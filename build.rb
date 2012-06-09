#!/usr/bin/env ruby

require 'fileutils'
require 'open3'
require 'time'


class FileNotFoundError < StandardError
end


class UnknownMapFilename < StandardError
end


module OpenMtbMap
  DEFAULT_STYLE = "wide"
  STYLES        = %w[ clas easy hike thin trad wide ]

  MKGMAP_DEFAULT_ARGS = [ '--area-name',
                          '--check-roundabout-flares',
                          '--check-roundabouts',
                          '--gmapsupp',
                          '--lower-case',
                          '--make-all-cycleways',
                          '--make-cycleways',
                          '--make-opposite-cycleways',
                          '--make-poi-index',
                          '--max-jobs',
                          '--net',
                          '--route',
                          '--show-profiles=1',
                          '--verbose', ]

  def self.create_map(name, style, date, pattern)
    file       = name.downcase.gsub(" ", "_").gsub("/", "-") + ".img"
    id         = map_id_from_files(".", pattern)
    style_file = Dir.glob("#{style}*.typ").first()

    exit_status = create_map_mkgmap(:file => file, :fid => id, :name => name,
                                    :pattern => pattern, :style => style_file,
                                    :index => (/6.*\.img/i =~ pattern))

    if 0 == exit_status && File.exists?(file)
      file_time = Time.parse(date)
      File.utime(file_time, file_time, file)
      file
    end
  end

  def self.create_map_mkgmap(options = {})
    opts = {
      :file    => "gmapsupp.img",
      :fid     => 6001,
      :index   => true,
      :name    => "GMAPSUPP",
      :pattern => "[67]*.img",
      :style   => "#{self::DEFAULT_STYLE}.typ",
    }.merge!(options)

    args  = MKGMAP_DEFAULT_ARGS.dup
    args << '--index'           if opts[:index]
    args << '--family-id="%s"'   % opts[:fid]
    args << '--description="%s"' % opts[:name]
    args << '--family-name="%s"' % opts[:name]
    args << '--series-name="%s"' % opts[:name]
    args << opts[:pattern]
    args << '"%s"' % opts[:style]

    exit_status = run_mkgmap(args)

    File.rename("gmapsupp.img", opts[:file])
    exit_status
  end

  def self.create_maps(archive, styles = [self::DEFAULT_STYLE])
    short_name = short_map_name(archive)
    date       = File.mtime(archive).strftime("%F")
    dir        = File.join(File.dirname(archive), short_name)
    name       = "Openmtbmap #{short_name} #{date}"
    maps       = []

    OpenMtbMap.extract(archive, dir)

    Dir.chdir(dir) do
      styles.each do |style|
        maps << create_map(name + " #{style}",        style, date, "6*.img")
        maps << create_map(name + " #{style} srtm",   style, date, "7*.img")
       #maps << create_map(name + " #{style} w/srtm", style, date, "[67]*.img")
      end
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

  def self.run_mkgmap(*args)
    run("sh", "-c", "java -Xmx3584M -jar ../mkgmap.jar " + args.join(" "))
  end

  def self.short_map_name(filename)
    translations = {
      "albania"                => "al",
      "alps"                   => "alp",
      "andorra"                => "ad",
      "austria"                => "at",
      "azores"                 => "azores",
      "belarus"                => "bz",
      "belgium"                => "be",
      "bosnia-herzegovina"     => "ba",
      "bulgaria"               => "bg",
      "croatia"                => "hr",
      "cyprus"                 => "cy",
      "czech_republic"         => "cz",
      "denmark"                => "dk",
      "estonia"                => "ee",
      "faroe_islands"          => "fo",
      "finland"                => "fi",
      "france"                 => "fr",
      "germany"                => "de",
      "great_britain"          => "uk",
      "greece"                 => "gr",
      "hungary"                => "hu",
      "iceland"                => "is",
      "ireland"                => "ie",
      "isle_of_man"            => "isleofman",
      "italy"                  => "it",
      "kosovo"                 => "ko",
      "latvia"                 => "lv",
      "liechtenstein"          => "li",
      "lithuania"              => "lt",
      "luxembourg"             => "lu",
      "macedonia"              => "mk",
      "malta"                  => "mt",
      "moldova"                => "md",
      "monaco"                 => "mo",
      "montenegro"             => "cs-mo",
      "netherlands"            => "nl",
      "norway"                 => "no",
      "poland"                 => "pl",
      "portugal"               => "pt",
      "romania"                => "ro",
      "russia-european-part"   => "ru",
      "serbia"                 => "cs-se",
      "slovakia"               => "sk",
      "slovenia"               => "si",
      "spain"                  => "es",
      "sweden"                 => "se",
      "switzerland"            => "ch",
      "turkey"                 => "tr",
      "ukraine"                => "ua",
      "baden-wuerttemberg"     => "de-bw",
      "bayern"                 => "de-by",
      "berlin"                 => "de-be",
      "brandenburg"            => "de-bb",
      "bremen"                 => "de-hb",
      "hamburg"                => "de-hh",
      "hessen"                 => "de-he",
      "mecklenburg-vorpommern" => "de-mv",
      "niedersachsen"          => "de-ni",
      "nordrhein-westfalen"    => "de-nw",
      "rheinland-pfalz"        => "de-rp",
      "saarland"               => "de-sl",
      "sachsen"                => "de-sn",
      "sachsen-anhalt"         => "de-st",
      "schleswig-holstein"     => "de-sh",
      "thueringen"             => "de-th",
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
  styles = (OpenMtbMap::STYLES & ARGV)
  styles << OpenMtbMap::DEFAULT_STYLE if styles.empty?

  ARGV.each do |archive|
    if File.exists? archive
      begin
        puts(archive)
        maps = OpenMtbMap.create_maps(archive, styles)
        maps.each { |map| puts("  #{map}") }
      rescue StandardError => e
        puts("  %s: %s" % [e.class, e.message])
      end
    end
  end
end
