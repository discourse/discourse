# frozen_string_literal: true

module DiscourseUpdates
  class << self
    def check_version
      attrs = {
        installed_version: Discourse::VERSION::STRING,
        installed_sha: (Discourse.git_version == "unknown" ? nil : Discourse.git_version),
        installed_describe: Discourse.full_version,
        git_branch: Discourse.git_branch,
        updated_at: updated_at,
      }

      unless updated_at.nil?
        attrs.merge!(
          latest_version: latest_version,
          critical_updates: critical_updates_available?,
          missing_versions_count: missing_versions_count,
        )
      end

      version_info = DiscourseVersionCheck.new(attrs)

      # replace -commit_count with +commit_count
      if version_info.installed_describe =~ /-(\d+)-/
        version_info.installed_describe =
          version_info.installed_describe.gsub(/-(\d+)-.*/, " +#{$1}")
      end

      if SiteSetting.version_checks?
        is_stale_data =
          (
            version_info.missing_versions_count == 0 &&
              version_info.latest_version != version_info.installed_version
          ) ||
            (
              version_info.missing_versions_count != 0 &&
                version_info.latest_version == version_info.installed_version
            )

        # Handle cases when version check data is old so we report something that makes sense
        if version_info.updated_at.nil? || last_installed_version != Discourse::VERSION::STRING || # never performed a version check # updated since the last version check
             is_stale_data
          Jobs.enqueue(:call_discourse_hub, all_sites: true)
          version_info.version_check_pending = true

          unless version_info.updated_at.nil?
            version_info.missing_versions_count = 0
            version_info.critical_updates = false
          end
        end

        version_info.stale_data =
          version_info.version_check_pending || (updated_at && updated_at < 48.hours.ago) ||
            is_stale_data
      end

      version_info
    end

    # last_installed_version is the installed version at the time of the last version check
    def last_installed_version
      Discourse.redis.get last_installed_version_key
    end

    def last_installed_version=(arg)
      Discourse.redis.set(last_installed_version_key, arg)
    end

    def latest_version
      Discourse.redis.get latest_version_key
    end

    def latest_version=(arg)
      Discourse.redis.set(latest_version_key, arg)
    end

    def missing_versions_count
      Discourse.redis.get(missing_versions_count_key).try(:to_i)
    end

    def missing_versions_count=(arg)
      Discourse.redis.set(missing_versions_count_key, arg)
    end

    def critical_updates_available?
      (Discourse.redis.get(critical_updates_available_key) || false) == "true"
    end

    def critical_updates_available=(arg)
      Discourse.redis.set(critical_updates_available_key, arg)
    end

    def updated_at
      t = Discourse.redis.get(updated_at_key)
      t ? Time.zone.parse(t) : nil
    end

    def updated_at=(time_with_zone)
      Discourse.redis.set updated_at_key, time_with_zone.as_json
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
          key = "#{missing_versions_key_prefix}:#{v["version"]}"
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

    def current_version
      last_installed_version || Discourse::VERSION::STRING
    end

    def new_features_payload
      response = Excon.new(new_features_endpoint).request(expects: [200], method: :Get)
      response.body
    end

    def update_new_features(payload = nil)
      payload ||= new_features_payload
      Discourse.redis.set(new_features_key, payload)
    end

    def new_features(force_refresh: false)
      update_new_features if force_refresh

      entries =
        begin
          JSON.parse(Discourse.redis.get(new_features_key))
        rescue StandardError
          nil
        end
      return nil if entries.nil?

      entries.map! do |item|
        next item if !item["experiment_setting"]

        item["experiment_setting"] = nil if !SiteSetting.respond_to?(item["experiment_setting"]) ||
          SiteSetting.type_supervisor.get_type(item["experiment_setting"].to_sym) != :bool
        item
      end

      entries.select! do |item|
        begin
          valid_version =
            item["discourse_version"].nil? ||
              Discourse.has_needed_version?(current_version, item["discourse_version"])

          valid_plugin_name =
            item["plugin_name"].blank? || Discourse.plugins_by_name[item["plugin_name"]].present?

          valid_version && valid_plugin_name
        rescue StandardError
          nil
        end
      end

      entries.sort_by { |item| Time.zone.parse(item["created_at"]).to_i }.reverse
    end

    def has_unseen_features?(user_id)
      entries = new_features
      return false if entries.nil?

      last_seen = new_features_last_seen(user_id)

      if last_seen.present?
        entries.select! { |item| Time.zone.parse(item["created_at"]) > last_seen }
      end

      entries.size > 0
    end

    def new_features_last_seen(user_id)
      last_seen = Discourse.redis.get new_features_last_seen_key(user_id)
      return nil if last_seen.blank?
      Time.zone.parse(last_seen)
    end

    def mark_new_features_as_seen(user_id)
      entries =
        begin
          JSON.parse(Discourse.redis.get(new_features_key))
        rescue StandardError
          nil
        end
      return nil if entries.nil?
      last_seen = entries.max_by { |x| x["created_at"] }
      Discourse.redis.set(new_features_last_seen_key(user_id), last_seen["created_at"])
    end

    def get_last_viewed_feature_date(user_id)
      date = Discourse.redis.hget(last_viewed_feature_dates_for_users_key, user_id.to_s)
      return if date.blank?
      Time.zone.parse(date)
    end

    def bump_last_viewed_feature_date(user_id, feature_date)
      Discourse.redis.hset(last_viewed_feature_dates_for_users_key, user_id.to_s, feature_date)
    end

    def clean_state
      Discourse.redis.del(
        last_installed_version_key,
        latest_version_key,
        critical_updates_available_key,
        missing_versions_count_key,
        updated_at_key,
        missing_versions_list_key,
        new_features_key,
        last_viewed_feature_dates_for_users_key,
        *Discourse.redis.keys("#{missing_versions_key_prefix}*"),
        *Discourse.redis.keys(new_features_last_seen_key("*")),
      )
    end

    def new_features_endpoint
      return "https://meta.discourse.org/new-features.json" if Rails.env.production?
      ENV["DISCOURSE_NEW_FEATURES_ENDPOINT"] || "http://localhost:4200/new-features.json"
    end

    private

    def last_installed_version_key
      "last_installed_version"
    end

    def latest_version_key
      "discourse_latest_version"
    end

    def critical_updates_available_key
      "critical_updates_available"
    end

    def missing_versions_count_key
      "missing_versions_count"
    end

    def updated_at_key
      "last_version_check_at"
    end

    def missing_versions_list_key
      "missing_versions"
    end

    def missing_versions_key_prefix
      "missing_version"
    end

    def new_features_key
      "new_features"
    end

    def new_features_last_seen_key(user_id)
      "new_features_last_seen_user_#{user_id}"
    end

    def last_viewed_feature_dates_for_users_key
      "last_viewed_feature_dates_for_users_hash"
    end
  end
end
