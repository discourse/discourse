module DiscourseUpdates

  class << self

    def check_version
      DiscourseVersionCheck.new(
        latest_version: latest_version || Discourse::VERSION::STRING,
        critical_updates: critical_update_available?,
        installed_version: Discourse::VERSION::STRING,
        installed_sha: (Discourse.git_version == 'unknown' ? nil : Discourse.git_version)
        # TODO: more info, like links and release messages
      )
    end

    def latest_version=(arg)
      $redis.set latest_version_key, arg
    end

    def latest_version
      $redis.get latest_version_key
    end

    def critical_update_available=(arg)
      $redis.set critical_updates_available_key, arg
    end

    def critical_update_available?
      ($redis.get(critical_updates_available_key) || false) == 'true'
    end


    private

      def latest_version_key
        'discourse_latest_version'
      end

      def critical_updates_available_key
        'critical_updates_available'
      end
  end
end