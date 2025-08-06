# frozen_string_literal: true

module DiscourseChatIntegration
  module Manager
    def self.guardian
      Guardian.new(User.find_by(username: SiteSetting.chat_integration_discourse_username))
    end

    def self.trigger_notifications(post_id)
      post = Post.find_by(id: post_id)

      # Abort if the chat_user doesn't have permission to see the post
      return if !guardian.can_see?(post)

      # Abort if the post is blank
      return if post.blank?

      # Abort if post is not either regular or a 'category_changed' whisper
      if (post.post_type != Post.types[:regular]) &&
           !(
             post.post_type == Post.types[:whisper] &&
               %w[category_changed].include?(post.action_code)
           )
        return
      end

      topic = post.topic
      return if topic.blank?

      # If it's a private message, filter rules by groups, otherwise filter rules by category
      if topic.archetype == Archetype.private_message
        group_ids_with_access = topic.topic_allowed_groups.pluck(:group_id)
        return if group_ids_with_access.empty?
        matching_rules =
          DiscourseChatIntegration::Rule.with_type("group_message").with_group_ids(
            group_ids_with_access,
          )
      else
        matching_rules =
          DiscourseChatIntegration::Rule.with_type("normal").with_category_id(topic.category_id)
        if topic.category # Also load the rules for the wildcard category
          matching_rules += DiscourseChatIntegration::Rule.with_type("normal").with_category_id(nil)
        end

        # If groups are mentioned, check for any matching rules and append them
        mentions = post.raw_mentions
        if mentions && mentions.length > 0
          groups = Group.where("LOWER(name) IN (?)", mentions)
          if groups.exists?
            matching_rules +=
              DiscourseChatIntegration::Rule.with_type("group_mention").with_group_ids(
                groups.map(&:id),
              )
          end
        end
      end

      matching_rules = matching_rules.select { |rule| rule.filter != "tag_added" } # ignore tag_added rules, now uses Automation

      # If tagging is enabled, thow away rules that don't apply to this topic
      if SiteSetting.tagging_enabled
        topic_tags = topic.tags.present? ? topic.tags.pluck(:name) : []
        matching_rules =
          matching_rules.select do |rule|
            next true if rule.tags.nil? || rule.tags.empty? # Filter has no tags specified
            any_tags_match = !((rule.tags & topic_tags).empty?)
            next any_tags_match # If any tags match, keep this filter, otherwise throw away
          end
      end

      # Sort by order of precedence
      t_prec = { "group_message" => 0, "group_mention" => 1, "normal" => 2 } # Group things win
      f_prec = { "mute" => 0, "thread" => 1, "watch" => 2, "follow" => 3 } #(mute always wins; thread beats watch beats follow)
      sort_func =
        proc { |a, b| [t_prec[a.type], f_prec[a.filter]] <=> [t_prec[b.type], f_prec[b.filter]] }
      matching_rules = matching_rules.sort(&sort_func)

      # Take the first rule for each channel
      uniq_func = proc { |rule| [rule.channel_id] }
      matching_rules = matching_rules.uniq(&uniq_func)

      # If a matching rule is set to mute, we can discard it now
      matching_rules = matching_rules.select { |rule| rule.filter != "mute" }

      # If this is not the first post, discard all "follow" rules. Unless it's a
      # category_changed action post. If category changed, filter out and rules
      # that aren't specific to a category
      if !post.is_first_post?
        matching_rules =
          if post.action_code == "category_changed"
            matching_rules.select { |rule| rule.category_id.present? }
          else
            matching_rules.select { |rule| rule.filter != "follow" }
          end
      end

      # All remaining rules now require a notification to be sent
      # If there are none left, abort
      return false if matching_rules.empty?

      # Loop through each rule, and trigger appropriate notifications
      matching_rules.each do |rule|
        # If there are any issues, skip to the next rule
        next unless channel = rule.channel
        next unless provider = ::DiscourseChatIntegration::Provider.get_by_name(channel.provider)
        next unless is_enabled = ::DiscourseChatIntegration::Provider.is_enabled(provider)

        begin
          provider.trigger_notification(post, channel, rule)
          channel.update_attribute("error_key", nil) if channel.error_key
        rescue => e
          if e.class == (DiscourseChatIntegration::ProviderError) && e.info.key?(:error_key) &&
               !e.info[:error_key].nil?
            channel.update_attribute("error_key", e.info[:error_key])
          else
            channel.update_attribute("error_key", "chat_integration.channel_exception")
          end
          channel.update_attribute("error_info", JSON.pretty_generate(e.try(:info)))

          # Log the error
          # Discourse.handle_job_exception(e,
          #   message: "Triggering notifications failed",
          #   extra: { provider_name: provider::PROVIDER_NAME,
          #            channel: rule.channel,
          #            post_id: post.id,
          #            error_info: e.class == DiscourseChatIntegration::ProviderError ? e.info : nil }
          # )
        end
      end
    end
  end
end
