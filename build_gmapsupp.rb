#!/usr/bin/env ruby

require 'ap'
require 'fileutils'
require 'open3'


class FileNotFoundError < StandardError
end


class UnknownMapFilename < StandardError
end


module OpenMtbMap
  def self.create_map(name, typ, date, pattern)
    file     = name.downcase.gsub(" ", "_").gsub("/", "-") + ".img"
    id       = map_id_from_files(".", pattern)
    gmt_typ  = prepare_typ(typ, id)
    gmt_args = '-j -o "%{file}" -f "%{id}" -m "%{name}" %{pattern} "%{typ}"' % {
      :file    => file,
      :id      => id,
      :name    => name,
      :pattern => pattern,
      :typ     => gmt_typ,
    }

    exit_status = run_gmt(gmt_args)

    if 0 == exit_status && File.exists?(file)
      file
    end
  end

  def self.create_maps(archive, typ = "clas")
    short_name = short_map_name(archive)
    date       = File.mtime(archive).strftime("%F")
    dir        = File.join(File.dirname(archive), short_name)
    name       = "Openmtbmap #{short_name} #{date} #{typ}"
    maps       = []

    OpenMtbMap.extract(archive, dir)
  
    Dir.chdir(dir) do
      maps << create_maps(name,             typ, date, "6*.img")
      maps << create_maps(name + " srtm",   typ, date, "7*.img")
      maps << create_maps(name + " w/srtm", typ, date, "[67]*.img")
    end

    maps.compact!
    maps.each do |map|
      FileUtils.mv(File.join(dir, map), ".")
    end
    
    FileUtils.remove_entry_secure(dir, true)
    maps
  end
  
  def self.extract(archive, output_dir)
    if /srtm/i =~ archive
      unzip(File.join(File.dirname(archive),
                      "openmtbmap_contourline_scripts.zip"),
            output_dir)
    end
  
    unzip(archive, output_dir)
    rename_files_downcase(output_dir)
  end

  def self.map_id_from_files(dir, pattern)
    filename = File.basename(Dir.glob(File.join(dir, pattern)).first())
    filename ? filename[0..3] : nil
  end

  def self.prepare_typ(typ, fid)
    gmt_typ = "01002468.typ"
    file    = Dir.glob("#{typ}*.typ").first()

    if file
      FileUtils.copy(file, gmt_typ)
      run_gmt("-wy", fid, gmt_typ)
    end

    gmt_typ
  end

  def self.rename_files_downcase(dir)
    Dir.chdir(dir) do
      Dir["**/*"].each {|f| File.rename(f, f.downcase)}
    end
  end

  def self.run(*cmd)
    Open3.popen3(*cmd) { |stdin, stdout, stderr, wait_thread|
      exit_status = wait_thread.value.exitstatus

      if 1 <= exit_status
        $stderr.puts(stdout.read())
        $stderr.puts(stderr.read())
      end

      exit_status
    }
  end

  def self.run_gmt(*args)
    run("sh", "-c", "wine gmt " + args.join(" "))
  end

  def self.short_map_name(filename)
    translations = {
      "alps"            => "alp",
      "austria"         => "at",
      "belgium"         => "be",
      "benelux"         => "benelux",
      "czechoslovakia"  => "cz-sk",
      "denmark"         => "dk",
      "finland"         => "fi",
      "france"          => "fr",
      "germany"         => "de",
      "great-britain"   => "uk",
      "great_britain"   => "uk",
      "greece"          => "gr",
      "ireland"         => "ie",
      "italy"           => "it",
      "liechtenstein"   => "li",
      "luxembourg"      => "lu",
      "monaco"          => "mo",
      "netherlands"     => "nl",
      "norway"          => "no",
      "poland"          => "pl",
      "portugal"        => "pt",
      "rheinland-pfalz" => "de-rp",
      "saarland"        => "de-sa",
      "spain"           => "es",
      "sweden"          => "se",
      "switzerland"     => "ch",
    }
  
    prefix     = ".*(openmtbmap_|mtb)(("
    suffix     = ")(_srtm)?)[_\.].*"
    longnames,
    shortnames = [:keys, :values].map { |method|
      Regexp.new(prefix + Regexp.union(translations.send(method).sort).to_s + suffix)
    }
    
    case filename
      when longnames
        translations[filename.gsub(longnames, "\\3")] + filename.gsub(longnames, "\\4")
      when shortnames
        filename.gsub(shortnames, "\\2")
      else
        raise UnknownMapFilename.new("Strange filename #{filename}")
    end
  end
  
  def self.unzip(archive, output_dir)
    unless File.exists? archive
      raise FileNotFoundError.new("File %s does not exist." % archive)
    end

    run("7z", "e", "-y", "-o#{output_dir}", archive)
  end
end


if __FILE__ == $0
  Process.setpriority(Process::PRIO_PROCESS, 0, 19)

  max_arg_size = ARGV.max_by { |a| a.size }.size

  ARGV.each do |archive|
    begin
      puts(archive)
      maps = OpenMtbMap.create_maps(archive, "clas")
      maps.each { |map| puts("  #{map}") }
    rescue StandardError => e
      puts("  %s: %s" % [e.class, e.message])
    end
  end
end
