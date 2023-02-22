# frozen_string_literal: true

module DiscourseAutomation
  module EventHandlers
    def self.handle_post_created_edited(post, action)
      return if post.post_type != Post.types[:regular] || post.user_id < 0

      name = DiscourseAutomation::Triggerable::POST_CREATED_EDITED

      DiscourseAutomation::Automation
        .where(trigger: name, enabled: true)
        .find_each do |automation|
          valid_trust_levels = automation.trigger_field("valid_trust_levels")
          if valid_trust_levels["value"]
            next unless valid_trust_levels["value"].include?(post.user.trust_level)
          end

          restricted_category = automation.trigger_field("restricted_category")
          if restricted_category["value"]
            category_id = post.topic&.category&.parent_category&.id || post.topic&.category&.id
            next if restricted_category["value"] != category_id
          end

          automation.trigger!("kind" => name, "action" => action, "post" => post)
        end
    end

    def self.handle_pm_created(topic)
      return if topic.user_id < 0

      user = topic.user
      target_usernames = topic.allowed_users.pluck(:username) - [user.username]
      return unless target_usernames.count == 1

      name = DiscourseAutomation::Triggerable::PM_CREATED

      DiscourseAutomation::Automation
        .where(trigger: name, enabled: true)
        .find_each do |automation|
          restricted_username = automation.trigger_field("restricted_user")["value"]
          next if restricted_username != target_usernames.first

          ignore_staff = automation.trigger_field("ignore_staff")
          next if ignore_staff["value"] && user.staff?

          valid_trust_levels = automation.trigger_field("valid_trust_levels")
          if valid_trust_levels["value"]
            next unless valid_trust_levels["value"].include?(user.trust_level)
          end

          automation.trigger!("kind" => name, "post" => topic.first_post)
        end
    end

    def self.handle_after_post_cook(post, cooked)
      return cooked if post.post_type != Post.types[:regular] || post.post_number > 1

      name = DiscourseAutomation::Triggerable::AFTER_POST_COOK

      DiscourseAutomation::Automation
        .where(trigger: name, enabled: true)
        .find_each do |automation|
          valid_trust_levels = automation.trigger_field("valid_trust_levels")
          if valid_trust_levels["value"]
            next unless valid_trust_levels["value"].include?(post.user.trust_level)
          end

          restricted_category = automation.trigger_field("restricted_category")
          if restricted_category["value"]
            category_id = post.topic&.category&.parent_category&.id || post.topic&.category&.id
            next if restricted_category["value"] != category_id
          end

          restricted_tags = automation.trigger_field("restricted_tags")
          if tag_names = restricted_tags["value"]
            found = false
            next if !post.topic

            post.topic.tags.each do |tag|
              found ||= tag_names.include?(tag.name)
              break if found
            end

            next if !found
          end

          if new_cooked = automation.trigger!("kind" => name, "post" => post, "cooked" => cooked)
            cooked = new_cooked
          end
        end

      cooked
    end

    def self.handle_user_promoted(user_id, new_trust_level, old_trust_level)
      trigger = DiscourseAutomation::Triggerable::USER_PROMOTED
      user = User.find_by(id: user_id)
      return if user.blank?

      # don't want to do anything if the user is demoted. this should probably
      # be a separate event in core
      return if new_trust_level < old_trust_level

      DiscourseAutomation::Automation
        .where(trigger: trigger, enabled: true)
        .find_each do |automation|
          trust_level_code_all =
            DiscourseAutomation::Triggerable::USER_PROMOTED_TRUST_LEVEL_CHOICES.first[:id]

          restricted_group_id = automation.trigger_field("restricted_group")["value"]
          trust_level_transition = automation.trigger_field("trust_level_transition")["value"]
          trust_level_transition = trust_level_transition || trust_level_code_all

          if restricted_group_id.present? &&
               !GroupUser.exists?(user_id: user_id, group_id: restricted_group_id)
            next
          end

          transition_code = "TL#{old_trust_level}#{new_trust_level}"
          if trust_level_transition == trust_level_code_all ||
               trust_level_transition == transition_code
            automation.trigger!(
              "kind" => trigger,
              "usernames" => [user.username],
              "placeholders" => {
                "trust_level_transition" =>
                  I18n.t(
                    "discourse_automation.triggerables.user_promoted.transition_placeholder",
                    from_level_name: TrustLevel.name(old_trust_level),
                    to_level_name: TrustLevel.name(new_trust_level),
                  ),
              },
            )
          end
        end
    end
  end
end
