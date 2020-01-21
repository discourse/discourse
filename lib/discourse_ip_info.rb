# frozen_string_literal: true

require 'maxminddb'
require 'resolv'

class DiscourseIpInfo
  include Singleton

  def initialize
    open_db(DiscourseIpInfo.path)
  end

  def open_db(path)
    @loc_mmdb = mmdb_load(File.join(path, 'GeoLite2-City.mmdb'))
    @asn_mmdb = mmdb_load(File.join(path, 'GeoLite2-ASN.mmdb'))
    @cache = LruRedux::ThreadSafeCache.new(2000)
  end

  def self.path
    @path ||= File.join(Rails.root, 'vendor', 'data')
  end

  def self.mmdb_path(name)
    File.join(path, "#{name}.mmdb")
  end

  def self.mmdb_download(name)

    if GlobalSetting.maxmind_license_key.blank?
      STDERR.puts "MaxMind IP database updates require a license"
      STDERR.puts "Please set DISCOURSE_MAXMIND_LICENSE_KEY to one you generated at https://www.maxmind.com"
      return
    end

    FileUtils.mkdir_p(path)

    url = "https://download.maxmind.com/app/geoip_download?license_key=#{GlobalSetting.maxmind_license_key}&edition_id=#{name}&suffix=tar.gz"

    gz_file = FileHelper.download(
      url,
      max_file_size: 100.megabytes,
      tmp_file_name: "#{name}.gz",
      validate_uri: false,
      follow_redirect: false
    )

    filename = File.basename(gz_file.path)

    dir = "#{Dir.tmpdir}/#{SecureRandom.hex}"

    Discourse::Utils.execute_command(
      "mkdir", "-p", dir
    )

    Discourse::Utils.execute_command(
      "cp",
      gz_file.path,
      "#{dir}/#{filename}"
    )

    Discourse::Utils.execute_command(
      "tar",
      "-xzvf",
      "#{dir}/#{filename}",
      chdir: dir
    )

    Dir["#{dir}/**/*.mmdb"].each do |f|
      FileUtils.mv(f, mmdb_path(name))
    end

  ensure
    FileUtils.rm_r(dir, force: true) if dir
    gz_file&.close!
  end

  def mmdb_load(filepath)
    begin
      MaxMindDB.new(filepath, MaxMindDB::LOW_MEMORY_FILE_READER)
    rescue Errno::ENOENT => e
      Rails.logger.warn("MaxMindDB (#{filepath}) could not be found: #{e}")
      nil
    rescue => e
      Discourse.warn_exception(e, message: "MaxMindDB (#{filepath}) could not be loaded.")
      nil
    end
  end

  def lookup(ip, locale: :en, resolve_hostname: false)
    ret = {}
    return ret if ip.blank?

    if @loc_mmdb
      begin
        result = @loc_mmdb.lookup(ip)
        if result&.found?
          ret[:country] = result.country.name(locale) || result.country.name
          ret[:country_code] = result.country.iso_code
          ret[:region] = result.subdivisions.most_specific.name(locale) || result.subdivisions.most_specific.name
          ret[:city] = result.city.name(locale) || result.city.name
          ret[:latitude] = result.location.latitude
          ret[:longitude] = result.location.longitude
          ret[:location] = ret.values_at(:city, :region, :country).reject(&:blank?).uniq.join(", ")
        end
      rescue => e
        Discourse.warn_exception(e, message: "IP #{ip} could not be looked up in MaxMind GeoLite2-City database.")
      end
    end

    if @asn_mmdb
      begin
        result = @asn_mmdb.lookup(ip)
        if result&.found?
          result = result.to_hash
          ret[:asn] = result["autonomous_system_number"]
          ret[:organization] = result["autonomous_system_organization"]
        end
      rescue => e
        Discourse.warn_exception(e, message: "IP #{ip} could not be looked up in MaxMind GeoLite2-ASN database.")
      end
    end

    # this can block for quite a while
    # only use it explicitly when needed
    if resolve_hostname
      begin
        result = Resolv::DNS.new.getname(ip)
        ret[:hostname] = result&.to_s
      rescue Resolv::ResolvError
      end
    end

    ret
  end

  def get(ip, locale: :en, resolve_hostname: false)
    ip = ip.to_s
    locale = locale.to_s.sub('_', '-')

    @cache["#{ip}-#{locale}-#{resolve_hostname}"] ||=
      lookup(ip, locale: locale, resolve_hostname: resolve_hostname)
  end

  def self.open_db(path)
    instance.open_db(path)
  end

  def self.get(ip, locale: :en, resolve_hostname: false)
    instance.get(ip, locale: locale, resolve_hostname: resolve_hostname)
  end
end
