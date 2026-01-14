# frozen_string_literal: true

module DiscourseChatIntegration
  module Helper
    def self.process_command(channel, tokens)
      guardian = DiscourseChatIntegration::Manager.guardian

      provider = channel.provider

      cmd = tokens.shift if tokens.size >= 1

      error_text = I18n.t("chat_integration.provider.#{provider}.parse_error")

      case cmd
      when "thread", "watch", "follow", "mute"
        return error_text if tokens.empty?
        # If the first token in the command is a tag, this rule applies to all categories
        category_name = tokens[0].start_with?("tag:") ? nil : tokens.shift

        if category_name
          category = Category.find_by(slug: category_name)
          unless category
            cat_list = (CategoryList.new(guardian).categories.map(&:slug)).join(", ")
            return(
              I18n.t(
                "chat_integration.provider.#{provider}.not_found.category",
                name: category_name,
                list: cat_list,
              )
            )
          end
        else
          category = nil # All categories
        end

        tags = []
        # Every remaining token must be a tag. If not, abort and send help text
        while tokens.size > 0
          token = tokens.shift
          if token.start_with?("tag:")
            tag_name = token.sub(/^tag:/, "")
          else
            return error_text
          end

          tag = Tag.find_by(name: tag_name)

          unless tag
            return I18n.t("chat_integration.provider.#{provider}.not_found.tag", name: tag_name)
          end
          tags.push(tag.name)
        end

        category_id = category.nil? ? nil : category.id
        case DiscourseChatIntegration::Helper.smart_create_rule(
          channel: channel,
          filter: cmd,
          category_id: category_id,
          tags: tags,
        )
        when :created
          I18n.t("chat_integration.provider.#{provider}.create.created")
        when :updated
          I18n.t("chat_integration.provider.#{provider}.create.updated")
        else
          I18n.t("chat_integration.provider.#{provider}.create.error")
        end
      when "remove"
        return error_text unless tokens.size == 1

        rule_number = tokens[0].to_i
        return error_text unless rule_number.to_s == tokens[0] # Check we were given a number

        if DiscourseChatIntegration::Helper.delete_by_index(channel, rule_number)
          I18n.t("chat_integration.provider.#{provider}.delete.success")
        else
          I18n.t("chat_integration.provider.#{provider}.delete.error")
        end
      when "status"
        DiscourseChatIntegration::Helper.status_for_channel(channel)
      when "help"
        I18n.t("chat_integration.provider.#{provider}.help")
      else
        error_text
      end
    end

    # Produce a string with a list of all rules associated with a channel
    def self.status_for_channel(channel)
      rules = channel.rules.order_by_precedence
      provider = channel.provider

      text = I18n.t("chat_integration.provider.#{provider}.status.header") + "\n"

      i = 1
      rules.each do |rule|
        category_id = rule.category_id

        case rule.type
        when "normal"
          if category_id.nil?
            category_name = I18n.t("chat_integration.all_categories")
          else
            category = Category.find_by(id: category_id)
            if category
              category_name = category.slug
            else
              category_name = I18n.t("chat_integration.deleted_category")
            end
          end
        when "group_mention", "group_message"
          group = Group.find_by(id: rule.group_id)
          if group
            category_name = I18n.t("chat_integration.#{rule.type}_template", name: group.name)
          else
            category_name = I18n.t("chat_integration.deleted_group")
          end
        end

        text << I18n.t(
          "chat_integration.provider.#{provider}.status.rule_string",
          index: i,
          filter: rule.filter,
          category: category_name,
        )

        if SiteSetting.tagging_enabled && (!rule.tags.nil?)
          text << I18n.t(
            "chat_integration.provider.#{provider}.status.rule_string_tags_suffix",
            tags: rule.tags.join(", "),
          )
        end

        text << "\n"
        i += 1
      end

      text << I18n.t("chat_integration.provider.#{provider}.status.no_rules") if rules.size == 0

      text
    end

    # Delete a rule based on its (1 based) index as seen in the
    # status_for_channel function
    def self.delete_by_index(channel, index)
      rules = channel.rules.order_by_precedence
      return false if index < (1) || index > (rules.size)
      :deleted if rules[index - 1].destroy
    end

    # Create a rule for a specific channel
    # Designed to be used by provider's "Slash commands"
    # Will intelligently adjust existing rules to avoid duplicates
    # Returns
    #     :updated if an existing rule has been updated
    #     :created if a new rule has been created
    #     false if there was an error
    def self.smart_create_rule(channel:, filter:, category_id: nil, tags: nil)
      existing_rules = DiscourseChatIntegration::Rule.with_channel(channel).with_type("normal")

      # Select the ones that have the same category
      same_category = existing_rules.select { |rule| rule.category_id == category_id }

      same_category_and_tags =
        same_category.select do |rule|
          (rule.tags.nil? ? [] : rule.tags.sort) == (tags.nil? ? [] : tags.sort)
        end

      if same_category_and_tags.size > 0
        # These rules have exactly the same criteria as what we're trying to create
        the_rule = same_category_and_tags.shift # Take out the first one

        same_category_and_tags.each do |rule| # Destroy all the others - they're duplicates
          rule.destroy
        end

        return :updated if the_rule.update(filter: filter) # Update the filter
        return false # Error, probably validation
      end

      same_category_and_filters = same_category.select { |rule| rule.filter == filter }

      if same_category_and_filters.size > 0
        # These rules are exactly the same, except for tags. Let's combine the tags together
        tags = [] if tags.nil?
        same_category_and_filters.each do |rule|
          tags = tags | rule.tags unless rule.tags.nil? # Append the tags together, avoiding duplicates by magic
        end

        the_rule = same_category_and_filters.shift # Take out the first one

        if the_rule.update(tags: tags) # Update the tags
          same_category_and_filters.each do |rule| # Destroy all the others - they're duplicates
            rule.destroy
          end
          return :updated
        end

        return false # Error
      end

      # This rule is unique! Create a new one:
      if Rule.new(channel: channel, filter: filter, category_id: category_id, tags: tags).save
        return :created
      end
      false
    end

    def self.save_transcript(transcript)
      secret = SecureRandom.hex
      redis_key = "chat_integration:transcript:#{secret}"
      Discourse.redis.setex(redis_key, 3600, transcript)
      secret
    end

    def self.formatted_display_name(user)
      return "@#{user.username}" if !SiteSetting.enable_names || user.name.blank?

      full_name = user.name
      full_name_normalized = User.normalize_username(full_name.strip)
      similar =
        full_name_normalized.gsub(" ", "_") == user.username_lower ||
          full_name_normalized.gsub(" ", "") == user.username_lower
      if similar && SiteSetting.prioritize_username_in_ux?
        "@#{user.username}"
      elsif similar
        full_name
      elsif SiteSetting.prioritize_username_in_ux?
        "@#{user.username} (#{full_name})"
      else
        "#{full_name} (@#{user.username})"
      end
    end
  end
end
