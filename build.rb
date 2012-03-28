#!/usr/bin/env ruby

require 'fileutils'
require 'open3'
require 'time'


class FileNotFoundError < StandardError
end


class UnknownMapFilename < StandardError
end


module OpenMtbMap
  def self.args_for_gmt(options = {})
    opts = {
      :file    => "gmapsupp.img",
      :fid     => 6001,
      :name    => "GMAPSUPP",
      :pattern => "[67]*.img",
      :typ     => "a.typ",
    }.merge!(options)

    gmt_args = []
    gmt_args << '-j'
    gmt_args << '-o "%s"' % opts[:file]
    gmt_args << '-f "%s"' % opts[:fid]
    gmt_args << '-m "%s"' % opts[:name]
    gmt_args << opts[:pattern]
    gmt_args << '"%s"' % opts[:typ]
    
    gmt_args.join(" ")
  end

  def self.args_for_mkgmap(options = {})
    opts = {
      :file    => "gmapsupp.img",
      :fid     => 6001,
      :index   => true,
      :name    => "GMAPSUPP",
      :pattern => "[67]*.img",
      :typ     => "a.typ",
    }.merge!(options)

    mkgmap_args = []
    mkgmap_args << '--product-id=1'
    mkgmap_args << '--family-id="%s"'   % opts[:fid]
    mkgmap_args << '--description="%s"' % opts[:name]
    mkgmap_args << '--family-name="%s"' % opts[:name]
    mkgmap_args << '--series-name="%s"' % opts[:name]
    mkgmap_args << '--area-name'
    mkgmap_args << '--check-roundabout-flares'
    mkgmap_args << '--check-roundabouts'
    mkgmap_args << '--gmapsupp'
    mkgmap_args << '--index' if opts[:index]
    mkgmap_args << '--lower-case'
    mkgmap_args << '--make-all-cycleways'
    mkgmap_args << '--make-cycleways'
    mkgmap_args << '--make-opposite-cycleways'
    mkgmap_args << '--make-poi-index'
    mkgmap_args << '--max-jobs'
    mkgmap_args << '--net'
    mkgmap_args << '--route'
    mkgmap_args << '--show-profiles=1'
    mkgmap_args << '--verbose'
    mkgmap_args << opts[:pattern]
    mkgmap_args << '"%s"' % opts[:typ]

    mkgmap_args.join(" ")
  end

  def self.create_map(name, typ, date, pattern)
    file         = name.downcase.gsub(" ", "_").gsub("/", "-") + ".img"
    id           = map_id_from_files(".", pattern)
    prepared_typ = prepare_typ(typ, id)

    if /6.*\.img/i =~ pattern
      exit_status = create_map_mkgmap(:file => file, :fid => id, :name => name,
                                      :pattern => pattern, :typ => prepared_typ)
    else
      exit_status = create_map_mkgmap(:file => file, :fid => id, :name => name,
                                      :pattern => pattern, :typ => prepared_typ, :index => false)
    end
    
    if 0 == exit_status && File.exists?(file)
      file_time = Time.parse(date)
      File.utime(file_time, file_time, file)
      file
    end
  end

  def self.create_map_gmt(options = {})
    run_gmt(args_for_gmt(options))
  end

  def self.create_map_mkgmap(options = {})
    opts = {
      :file => "gmapsupp.img",
    }.merge!(options)

    exit_status = run_mkgmap(args_for_mkgmap(opts))

    begin
      File.rename("gmapsupp.img", opts[:file])
    rescue
    end

    exit_status
  end

  def self.create_maps(archive, typ = "clas")
    short_name = short_map_name(archive)
    date       = File.mtime(archive).strftime("%F")
    dir        = File.join(File.dirname(archive), short_name)
    name       = "Openmtbmap #{short_name} #{date} #{typ}"
    maps       = []

    OpenMtbMap.extract(archive, dir)
  
    Dir.chdir(dir) do
      maps << create_map(name,             typ, date, "6*.img")
      maps << create_map(name + " srtm",   typ, date, "7*.img")
      #maps << create_map(name + " w/srtm", typ, date, "[67]*.img")
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
    prepared_typ = "prepared.typ"
    file         = Dir.glob("#{typ}*.typ").first()

    if file
      FileUtils.copy(file, prepared_typ)
      run_gmt("-wy", fid, prepared_typ)
    end

    prepared_typ
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

  def self.run_mkgmap(*args)
    run("sh", "-c", "java -Xmx3584M -jar ../mkgmap.jar " + args.join(" "))
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
