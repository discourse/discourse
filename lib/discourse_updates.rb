# frozen_string_literal: true

module DiscourseUpdates

  class << self

    def check_version
      attrs = {
        installed_version: Discourse::VERSION::STRING,
        installed_sha: (Discourse.git_version == 'unknown' ? nil : Discourse.git_version),
        installed_describe: Discourse.full_version,
        git_branch: Discourse.git_branch,
        updated_at: updated_at,
      }

      unless updated_at.nil?
        attrs.merge!(
          latest_version: latest_version,
          critical_updates: critical_updates_available?,
          missing_versions_count: missing_versions_count
        )
      end

      version_info = DiscourseVersionCheck.new(attrs)

      # replace -commit_count with +commit_count
      if version_info.installed_describe =~ /-(\d+)-/
        version_info.installed_describe = version_info.installed_describe.gsub(/-(\d+)-.*/, " +#{$1}")
      end

      if SiteSetting.version_checks?
        is_stale_data =
          (version_info.missing_versions_count == 0 && version_info.latest_version != version_info.installed_version) ||
          (version_info.missing_versions_count != 0 && version_info.latest_version == version_info.installed_version)

        # Handle cases when version check data is old so we report something that makes sense
        if version_info.updated_at.nil? || # never performed a version check
           last_installed_version != Discourse::VERSION::STRING || # upgraded since the last version check
           is_stale_data

          Jobs.enqueue(:version_check, all_sites: true)
          version_info.version_check_pending = true

          unless version_info.updated_at.nil?
            version_info.missing_versions_count = 0
            version_info.critical_updates = false
          end
        end

        version_info.stale_data =
          version_info.version_check_pending ||
          (updated_at && updated_at < 48.hours.ago) ||
          is_stale_data
      end

      version_info
    end

    # last_installed_version is the installed version at the time of the last version check
    def last_installed_version
      Discourse.redis.get last_installed_version_key
    end

    def latest_version
      Discourse.redis.get latest_version_key
    end

    def missing_versions_count
      Discourse.redis.get(missing_versions_count_key).try(:to_i)
    end

    def critical_updates_available?
      (Discourse.redis.get(critical_updates_available_key) || false) == 'true'
    end

    def updated_at
      t = Discourse.redis.get(updated_at_key)
      t ? Time.zone.parse(t) : nil
    end

    def updated_at=(time_with_zone)
      Discourse.redis.set updated_at_key, time_with_zone.as_json
    end

    ['last_installed_version', 'latest_version', 'missing_versions_count', 'critical_updates_available'].each do |name|
      eval "define_method :#{name}= do |arg|
        Discourse.redis.set #{name}_key, arg
      end"
    end

    def missing_versions=(versions)
      # delete previous list from redis
      prev_keys = Discourse.redis.lrange(missing_versions_list_key, 0, 4)
      if prev_keys
        Discourse.redis.del prev_keys
        Discourse.redis.del(missing_versions_list_key)
      end

      if versions.present?
        # store the list in redis
        version_keys = []
        versions[0, 5].each do |v|
          key = "#{missing_versions_key_prefix}:#{v['version']}"
          Discourse.redis.mapped_hmset key, v
          version_keys << key
        end
        Discourse.redis.rpush missing_versions_list_key, version_keys
      end

      versions || []
    end

    def missing_versions
      keys = Discourse.redis.lrange(missing_versions_list_key, 0, 4) # max of 5 versions
      keys.present? ? keys.map { |k| Discourse.redis.hgetall(k) } : []
    end

    private

    def last_installed_version_key
      'last_installed_version'
    end

    def latest_version_key
      'discourse_latest_version'
    end

    def critical_updates_available_key
      'critical_updates_available'
    end

    def missing_versions_count_key
      'missing_versions_count'
    end

    def updated_at_key
      'last_version_check_at'
    end

    def missing_versions_list_key
      'missing_versions'
    end

    def missing_versions_key_prefix
      'missing_version'
    end
  end
end
