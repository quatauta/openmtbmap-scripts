#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'time'

class FileNotFoundError < StandardError
end

class UnknownMapFilename < StandardError
end

module OpenMtbMap
  DEFAULT_STYLES = %w(wide)
  STYLES         = %w(clas easy hike thin trad wide)

  DEFAULT_SRTM_INTEGRATIONS = %w(without separate)
  SRTM_INTEGRATIONS         = %w(without separate integrated)

  MKGMAP_DEFAULT_ARGS = %w(--add-pois-to-lines
                           --area-name
                           --check-roundabout-flares
                           --check-roundabouts
                           --cycle-map
                           --gmapsupp
                           --housenumbers
                           --index
                           --link-pois-to-ways
                           --location-autofill=is_in
                           --lower-case
                           --make-all-cycleways
                           --make-cycleways
                           --make-opposite-cycleways
                           --make-poi-index
                           --max-jobs
                           --name-tag-list=name:de,name:lu,int_name,name
                           --net
                           --poi-address
                           --preserve-element-order
                           --process-destination
                           --process-exits
                           --route
                           --show-profiles=1
                           --unicode
                           --x-split-name-index
                           --verbose)

  MAP_NAMES_CONTINENTS = Hash[*(%w(africa                    af
                                   asia                      as
                                   australia-oceania         oc-au
                                   central-america           am
                                   europe                    eu
                                   south-america             sa))]

  MAP_NAMES_COUNTRIES = Hash[*(%w(azerbaijan                az
                                  china                     cn
                                  gcc_states                gcc
                                  canary-islands            es-ic
                                  india                     in
                                  indonesia                 id
                                  iran                      ir
                                  iraq                      iq
                                  israel_and_palestine      il-ps
                                  japan                     jp
                                  kazakhstan                kz
                                  kyrgyzstan                kg
                                  malaysia_singapore_brunei my-sg-bn
                                  mongolia                  mn
                                  pakistan                  pk
                                  philippines               ph
                                  taiwan                    tw
                                  turkmenistan              tm
                                  uzbekistan                uz
                                  vietnam                   vn
                                  canary_islands            canary
                                  libya                     ly
                                  madagascar                mg
                                  morocco                   ma
                                  somalia                   so
                                  south_africa_and_lesotho  za-ls
                                  tanzania                  tz
                                  albania                   al
                                  alps                      alp
                                  andorra                   ad
                                  austria                   at
                                  azores                    azores
                                  belarus                   bz
                                  belgium                   be
                                  bosnia-herzegovina        ba
                                  bulgaria                  bg
                                  croatia                   hr
                                  cyprus                    cy
                                  czech_republic            cz
                                  denmark                   dk
                                  estonia                   ee
                                  faroe_islands             fo
                                  finland                   fi
                                  france                    fr
                                  germany                   de
                                  great_britain             uk
                                  greece                    gr
                                  hungary                   hu
                                  iceland                   is
                                  ireland                   ie
                                  isle_of_man               isleofman
                                  italy                     it
                                  kosovo                    ko
                                  latvia                    lv
                                  liechtenstein             li
                                  lithuania                 lt
                                  luxembourg                lu
                                  macedonia                 mk
                                  malta                     mt
                                  moldova                   md
                                  monaco                    mo
                                  montenegro                cs-mo
                                  netherlands               nl
                                  norway                    no
                                  poland                    pl
                                  portugal                  pt
                                  romania                   ro
                                  russia-european-part      ru-eu
                                  serbia                    cs-se
                                  slovakia                  sk
                                  slovenia                  si
                                  spain                     es
                                  sweden                    se
                                  switzerland               ch
                                  turkey                    tr
                                  ukraine                   ua))]

  MAP_NAMES_GERMANY = Hash[*(%w(baden-wuerttemberg        de-bw
                                bayern                    de-by
                                berlin                    de-be
                                brandenburg               de-bb
                                bremen                    de-hb
                                hamburg                   de-hh
                                hessen                    de-he
                                mecklenburg-vorpommern    de-mv
                                niedersachsen             de-ni
                                nordrhein-westfalen       de-nw
                                rheinland-pfalz           de-rp
                                saarland                  de-sl
                                sachsen                   de-sn
                                sachsen-anhalt            de-st
                                schleswig-holstein        de-sh
                                thueringen                de-th))]

  MAP_NAMES = MAP_NAMES_CONTINENTS.merge(MAP_NAMES_COUNTRIES).merge(MAP_NAMES_GERMANY)

  def self.create_map(options = {})
    opts = {
      name:    nil,
      style:   nil,
      date:    nil,
      pattern: '[67]*.img',
    }.merge!(options)

    file       = map_filename(opts[:name])
    id         = map_id_from_files('.', opts[:pattern])
    style_file = Dir.glob("#{opts[:style]}*.typ").first

    exit_status = create_map_mkgmap(file:    file,
                                    fid:     id,
                                    name:    opts[:name],
                                    pattern: opts[:pattern],
                                    style:   style_file,
                                    index:   (/6.*\.img/i =~ opts[:pattern]))

    if exit_status.zero? && File.exist?(file)
      update_file_utime(file, Time.parse(opts[:date]))
      file
    end
  end

  def self.map_filename(name)
    name.downcase.tr(' ', '_').tr('/', '-') + '.img'
  end

  def self.update_file_utime(file, time)
    File.utime(time, time, file) if File.exist?(file)
    file
  end

  def self.create_map_mkgmap(options = {})
    opts = {
      file:    'gmapsupp.img',
      fid:     6001,
      index:   true,
      name:    'GMAPSUPP',
      pattern: '[67]*.img',
      style:   "#{DEFAULT_STYLES.first}.typ",
    }.merge!(options)

    args  = MKGMAP_DEFAULT_ARGS.dup
    args << '--index'           if opts[:index]
    args << "--family-id='%s'"   % opts[:fid]
    args << "--description='%s'" % opts[:name]
    args << "--family-name='%s'" % opts[:name]
    args << "--series-name='%s'" % opts[:name]
    args << opts[:pattern]
    args << "'%s'" % opts[:style]

    exit_status = run_mkgmap(args)

    File.rename('gmapsupp.img', opts[:file])
    exit_status
  end

  def self.create_maps(options = {})
    opts = {
      file:   '',
      styles: [DEFAULT_STYLES],
      srtm:   [DEFAULT_SRTM_INTEGRATIONS],
    }.merge!(options)

    short_name = short_map_name(opts[:file])
    date       = File.mtime(opts[:file]).strftime('%F')
    dir        = File.join(File.dirname(opts[:file]), short_name)
    name       = "Openmtbmap #{short_name} #{date}"
    maps       = []

    OpenMtbMap.extract(opts[:file], dir)

    Dir.chdir(dir) do
      opts[:styles].each do |style|
        if opts[:srtm].include? 'without'
          maps << create_map(name: name + " #{style}", style: style,
                             date: date, pattern: '6*.img')
        end

        if opts[:srtm].include? 'separate'
          maps << create_map(name: name + " #{style} srtm", style: style,
                             date: date, pattern: '7*.img')
        end

        if opts[:srtm].include? 'integrated'
          maps << create_map(name: name + " #{style} w/srtm", style: style,
                             date: date, pattern: '[67]*.img')
        end
      end
    end

    maps.compact!
    maps.each do |map|
      FileUtils.mv(File.join(dir, map), '.')
    end

    FileUtils.remove_entry_secure(dir, true)
    maps
  end

  def self.extract(archive, output_dir)
    if /srtm/i =~ archive
      unzip(File.join(File.dirname(archive),
                      'openmtbmap_contourline_scripts.zip'),
            output_dir)
    end

    unzip(archive, output_dir)
    rename_files_downcase(output_dir)
  end

  def self.map_id_from_files(dir, pattern)
    filename = File.basename(Dir.glob(File.join(dir, pattern)).first)
    filename ? filename[0..3] : nil
  end

  def self.rename_files_downcase(dir)
    Dir.chdir(dir) do
      Dir['**/*'].each { |f| File.rename(f, f.downcase) }
    end
  end

  def self.run(*cmd)
    Open3.popen3(*cmd) do |_stdin, stdout, stderr, wait_thread|
      exit_status = wait_thread.value.exitstatus

      if 1 <= exit_status
        $stderr.puts(stdout.read)
        $stderr.puts(stderr.read)
      end

      exit_status
    end
  end

  def self.run_mkgmap(*args)
    run('sh', '-c', 'java -Xmx3584M -jar ../mkgmap.jar ' + args.join(' '))
  end

  def self.short_map_name(filename)
    prefix     = '.*(openmtbmap_|mtb|velomap_|velo)(('
    suffix     = ')(_srtm)?)[_\.].*'
    longnames,
    shortnames = [:keys, :values].map do |method|
      Regexp.new(prefix + Regexp.union(MAP_NAMES.send(method).sort).to_s + suffix)
    end

    case filename
    when longnames
      MAP_NAMES[filename.gsub(longnames, '\\3')] + filename.gsub(longnames, '\\4')
    when shortnames
      filename.gsub(shortnames, '\\2')
    else
      raise UnknownMapFilename.new('Strange filename %s' % filename)
    end
  end

  def self.unzip(archive, output_dir)
    unless File.exist? archive
      raise FileNotFoundError.new('File %s does not exist.' % archive)
    end

    run('7z', 'e', '-y', "-o#{output_dir}", archive)
  end
end

if __FILE__ == $PROGRAM_NAME
  Process.setpriority(Process::PRIO_PROCESS, 0, 19)
  styles = OpenMtbMap::STYLES & ARGV
  styles = OpenMtbMap::DEFAULT_STYLES if styles.empty?

  srtm = OpenMtbMap::SRTM_INTEGRATIONS & ARGV
  srtm = OpenMtbMap::DEFAULT_SRTM_INTEGRATIONS if srtm.empty?

  files = ARGV.select { |arg| File.exist? arg }
  files = Dir['{mtb,velo}*.exe'].sort if files.empty?

  puts 'Building maps for Garmin devices'
  puts 'Files:  %s' % files.join(', ')
  puts 'Styles: %s' % styles.join(', ')
  puts 'SRTM:   %s' % srtm.join(', ')
  puts

  begin
    files.each do |file|
      begin
        puts(file)
        maps = OpenMtbMap.create_maps(file:   file,
                                      styles: styles,
                                      srtm:   srtm)
        maps.each { |map| puts("  #{map}") }
      rescue StandardError => e
        puts('  %s: %s' % [e.class, e.message])
      end
    end
  rescue Interrupt => e
    puts('')
    puts('Interrupted.')
  end
end
