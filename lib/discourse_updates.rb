module DiscourseUpdates

  class << self

    def check_version
      version_info = if updated_at.nil?
        DiscourseVersionCheck.new(
          installed_version: Discourse::VERSION::STRING,
          installed_sha: (Discourse.git_version == 'unknown' ? nil : Discourse.git_version),
          updated_at: nil
        )
      else
        DiscourseVersionCheck.new(
          latest_version: latest_version,
          critical_updates: critical_updates_available?,
          installed_version: Discourse::VERSION::STRING,
          installed_sha: (Discourse.git_version == 'unknown' ? nil : Discourse.git_version),
          missing_versions_count: missing_versions_count,
          updated_at: updated_at
        )
      end

      if version_info.updated_at.nil? or
          (version_info.missing_versions_count == 0 and version_info.latest_version != version_info.installed_version)
        # Version check data is out of date.
        Jobs.enqueue(:version_check, all_sites: true)
      end

      version_info
    end

    def latest_version
      $redis.get latest_version_key
    end

    def missing_versions_count
      $redis.get(missing_versions_count_key).try(:to_i)
    end

    def critical_updates_available?
      ($redis.get(critical_updates_available_key) || false) == 'true'
    end

    def updated_at
      t = $redis.get(updated_at_key)
      t ? Time.zone.parse(t) : nil
    end

    def updated_at=(time_with_zone)
      $redis.set updated_at_key, time_with_zone.as_json
    end

    ['latest_version', 'missing_versions_count', 'critical_updates_available'].each do |name|
      eval "define_method :#{name}= do |arg|
        $redis.set #{name}_key, arg
      end"
    end


    private

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
  end
end