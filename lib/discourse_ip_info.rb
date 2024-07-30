# frozen_string_literal: true

require "maxminddb"
require "resolv"

class DiscourseIpInfo
  include Singleton

  def initialize
    open_db(DiscourseIpInfo.path)
  end

  def open_db(path)
    @loc_mmdb = mmdb_load(File.join(path, "GeoLite2-City.mmdb"))
    @asn_mmdb = mmdb_load(File.join(path, "GeoLite2-ASN.mmdb"))
    @cache = LruRedux::ThreadSafeCache.new(2000)
  end

  def self.path
    @path ||= File.join(Rails.root, "vendor", "data")
  end

  def self.mmdb_path(name)
    File.join(path, "#{name}.mmdb")
  end

  def self.mmdb_download(name)
    extra_headers = {}

    url =
      if GlobalSetting.maxmind_mirror_url.present?
        File.join(GlobalSetting.maxmind_mirror_url, "#{name}.tar.gz").to_s
      else
        license_key = GlobalSetting.maxmind_license_key

        if license_key.blank?
          STDERR.puts "MaxMind IP database download requires an account ID and a license key"
          STDERR.puts "Please set DISCOURSE_MAXMIND_ACCOUNT_ID and DISCOURSE_MAXMIND_LICENSE_KEY. See https://meta.discourse.org/t/configure-maxmind-for-reverse-ip-lookups/173941 for more details."
          return
        end

        account_id = GlobalSetting.maxmind_account_id

        if account_id.present?
          extra_headers[
            "Authorization"
          ] = "Basic #{Base64.strict_encode64("#{account_id}:#{license_key}")}"

          "https://download.maxmind.com/geoip/databases/#{name}/download?suffix=tar.gz"
        else
          # This URL is not documented by MaxMind, but it works but we don't know when it will stop working. Therefore,
          # we are deprecating this in 3.3 and will remove it in 3.4. An admin dashboard warning has been added to inform
          # site admins about this deprecation. See `ProblemCheck::MaxmindDbConfiguration` for more information.
          "https://download.maxmind.com/app/geoip_download?license_key=#{license_key}&edition_id=#{name}&suffix=tar.gz"
        end
      end

    gz_file =
      FileHelper.download(
        url,
        max_file_size: 100.megabytes,
        tmp_file_name: "#{name}.gz",
        validate_uri: false,
        follow_redirect: true,
        extra_headers:,
      )

    filename = File.basename(gz_file.path)

    dir = "#{Dir.tmpdir}/#{SecureRandom.hex}"

    Discourse::Utils.execute_command("mkdir", "-p", dir)
    Discourse::Utils.execute_command("cp", gz_file.path, "#{dir}/#{filename}")
    Discourse::Utils.execute_command("tar", "-xzvf", "#{dir}/#{filename}", chdir: dir)

    Dir["#{dir}/**/*.mmdb"].each { |f| FileUtils.mv(f, mmdb_path(name)) }
  rescue => e
    Discourse.warn_exception(e, message: "MaxMind database #{name} download failed.")
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
          ret[:region] = result.subdivisions.most_specific.name(locale) ||
            result.subdivisions.most_specific.name
          ret[:city] = result.city.name(locale) || result.city.name
          ret[:latitude] = result.location.latitude
          ret[:longitude] = result.location.longitude
          ret[:location] = ret.values_at(:city, :region, :country).reject(&:blank?).uniq.join(", ")

          # used by plugins or API to locate users more accurately
          ret[:geoname_ids] = [
            result.continent.geoname_id,
            result.country.geoname_id,
            result.city.geoname_id,
            *result.subdivisions.map(&:geoname_id),
          ]
          ret[:geoname_ids].compact!
        end
      rescue => e
        Discourse.warn_exception(
          e,
          message: "IP #{ip} could not be looked up in MaxMind GeoLite2-City database.",
        )
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
        Discourse.warn_exception(
          e,
          message: "IP #{ip} could not be looked up in MaxMind GeoLite2-ASN database.",
        )
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
    locale = locale.to_s.sub("_", "-")

    @cache["#{ip}-#{locale}-#{resolve_hostname}"] ||= lookup(
      ip,
      locale: locale,
      resolve_hostname: resolve_hostname,
    )
  end

  def self.open_db(path)
    instance.open_db(path)
  end

  def self.get(ip, locale: :en, resolve_hostname: false)
    instance.get(ip, locale: locale, resolve_hostname: resolve_hostname)
  end
end
