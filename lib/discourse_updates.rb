module DiscourseUpdates

  class << self

    def check_version
      DiscourseVersionCheck.new(
        latest_version: latest_version || Discourse::VERSION::STRING,
        critical_updates: critical_updates_available?,
        installed_version: Discourse::VERSION::STRING,
        installed_sha: (Discourse.git_version == 'unknown' ? nil : Discourse.git_version),
        missing_versions_count: missing_versions_count || nil
        # TODO: more info, like links and release messages
      )
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
  end
end