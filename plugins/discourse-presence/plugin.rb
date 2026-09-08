# frozen_string_literal: true

# name: discourse-presence
# about: Show which users are replying to a topic, or editing a post
# version: 2.0
# authors: André Pereira, David Taylor, tgxworld
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-presence

enabled_site_setting :presence_enabled

register_asset "stylesheets/presence.scss"

after_initialize do
  register_presence_channel_prefix("discourse-presence") do |channel_name|
    staff_groups = [::Group::AUTO_GROUPS[:admins], ::Group::AUTO_GROUPS[:moderators]]

    if topic_id = channel_name[%r{/discourse-presence/reply/(\d+)}, 1]
      topic = Topic.find(topic_id)
      config = PresenceChannel::Config.new

      if topic.private_message?
        config.allowed_user_ids = topic.allowed_users.pluck(:id)
        config.allowed_group_ids = topic.allowed_groups.pluck(:group_id) + staff_groups
      elsif secure_group_ids = topic.secure_group_ids
        config.allowed_group_ids = secure_group_ids + [::Group::AUTO_GROUPS[:admins]]
      else
        # config.public=true would make data available to anon, so use the tl0 group instead
        config.allowed_group_ids = [::Group::AUTO_GROUPS[:trust_level_0]]
      end

      config
    elsif topic_id = channel_name[%r{/discourse-presence/whisper/(\d+)}, 1]
      topic = Topic.find(topic_id)
      config = PresenceChannel::Config.new

      if topic.private_message?
        config.allowed_user_ids = topic.allowed_users.pluck(:id)
        config.allowed_group_ids = topic.allowed_groups.pluck(:id).presence
      else
        config.allowed_group_ids = SiteSetting.whispers_allowed_groups_map
        config.allowed_group_ids &= topic.secure_group_ids if topic.secure_group_ids
      end

      config
      whisper_allowed_group_ids = SiteSetting.whispers_allowed_groups_map

      if !topic.private_message? && topic.shared_draft?
        shared_draft_group_ids = SiteSetting.shared_drafts_allowed_groups_map
        required_group_ids = [whisper_allowed_group_ids]
        if (
             shared_draft_group_ids &
               [::Group::AUTO_GROUPS[:everyone], ::Group::AUTO_GROUPS[:logged_in_users]]
           ).blank?
          required_group_ids << shared_draft_group_ids
        end
        required_group_ids << topic.secure_group_ids if topic.secure_group_ids
        shared_group_ids = required_group_ids.reduce(:&)
        allowed_users = GroupUser.where(group_id: required_group_ids.first)

        required_group_ids
          .drop(1)
          .each do |group_ids|
            allowed_users =
              allowed_users.where(user_id: GroupUser.where(group_id: group_ids).select(:user_id))
          end

        if shared_group_ids.present?
          allowed_users =
            allowed_users.where.not(
              user_id: GroupUser.where(group_id: shared_group_ids).select(:user_id),
            )
        end

        allowed_user_ids = allowed_users.distinct.pluck(:user_id)

        # Admins bypass shared-draft visibility unless secured categories are suppressed.
        if !SiteSetting.suppress_secured_categories_from_admin &&
             !whisper_allowed_group_ids.include?(::Group::AUTO_GROUPS[:admins])
          allowed_user_ids.concat(
            GroupUser
              .where(group_id: whisper_allowed_group_ids)
              .where(
                user_id: GroupUser.where(group_id: ::Group::AUTO_GROUPS[:admins]).select(:user_id),
              )
              .distinct
              .pluck(:user_id),
          )
        else
          if !SiteSetting.suppress_secured_categories_from_admin
            shared_group_ids << ::Group::AUTO_GROUPS[:admins]
          end
        end

        next(
          PresenceChannel::Config.new(
            allowed_user_ids: allowed_user_ids.uniq.presence,
            allowed_group_ids: shared_group_ids.uniq.presence,
          )
        )
      end

      if topic.private_message?
        topic_allowed_group_ids = topic.allowed_groups.pluck(:id)
        topic_allowed_user_ids = topic.all_allowed_users.pluck(:id)
      elsif secure_group_ids = topic.secure_group_ids
        topic_allowed_group_ids = secure_group_ids.dup
        topic_allowed_user_ids = []
      else
        next PresenceChannel::Config.new(allowed_group_ids: whisper_allowed_group_ids)
      end

      if !SiteSetting.suppress_secured_categories_from_admin
        topic_allowed_group_ids << ::Group::AUTO_GROUPS[:admins]
      end

      shared_group_ids = whisper_allowed_group_ids & topic_allowed_group_ids
      whisper_only_group_ids = whisper_allowed_group_ids - shared_group_ids
      topic_only_group_ids = topic_allowed_group_ids - shared_group_ids

      allowed_user_ids =
        if topic.private_message? && whisper_only_group_ids.present?
          topic_allowed_user_ids &
            GroupUser.where(group_id: whisper_only_group_ids).distinct.pluck(:user_id)
        else
          []
        end

      # Presence configs combine groups with OR, so only cross-group members need user entries.
      if whisper_only_group_ids.present? && topic_only_group_ids.present?
        allowed_user_ids.concat(
          GroupUser
            .where(group_id: whisper_only_group_ids)
            .where(user_id: GroupUser.where(group_id: topic_only_group_ids).select(:user_id))
            .distinct
            .pluck(:user_id),
        )
      end

      PresenceChannel::Config.new(
        allowed_user_ids: allowed_user_ids.uniq.presence,
        allowed_group_ids: shared_group_ids.presence,
      )
    elsif post_id = channel_name[%r{/discourse-presence/edit/(\d+)}, 1]
      post = Post.find(post_id)
      topic = Topic.find(post.topic_id)

      config = PresenceChannel::Config.new
      config.allowed_group_ids = staff_groups

      # Locked posts are staff only
      next config if post.locked?

      # Whispers posts are for allowed whisper groups
      if post.whisper?
        if topic.private_message?
          config.allowed_user_ids = topic.allowed_users.pluck(:id)
          config.allowed_group_ids += topic.allowed_groups.pluck(:group_id)
        else
          whisper_allowed_group_ids = SiteSetting.whispers_allowed_groups_map
          whisper_allowed_group_ids &= topic.secure_group_ids if topic.secure_group_ids
          config.allowed_group_ids += whisper_allowed_group_ids
        end
        next config
      end

      config.allowed_user_ids = [post.user_id] if post.user.guardian.can_see?(topic)

      if topic.private_message? && post.wiki
        # Ignore trust level and just publish to all allowed groups since
        # trying to figure out which users in the allowed groups have
        # the necessary trust levels can lead to a large array of user ids
        # if the groups are big.
        config.allowed_user_ids ||= []
        config.allowed_user_ids += topic.allowed_users.pluck(:id)
        config.allowed_group_ids += topic.allowed_groups.pluck(:id)
      elsif post.wiki
        wiki_post_allowed_group_ids = SiteSetting.edit_wiki_post_allowed_groups_map
        if secure_group_ids = topic.secure_group_ids
          wiki_post_allowed_group_ids &= secure_group_ids
        end
        config.allowed_group_ids += wiki_post_allowed_group_ids
      end

      if !topic.private_message? && SiteSetting.edit_all_post_groups_map.present?
        edit_all_post_group_ids = SiteSetting.edit_all_post_groups_map
        if secure_group_ids = topic.secure_group_ids
          edit_all_post_group_ids &= secure_group_ids
        end
        config.allowed_group_ids += edit_all_post_group_ids
      end

      if SiteSetting.enable_category_group_moderation? && topic.category
        category_moderating_group_ids = topic.category.moderating_groups.pluck(:id)
        category_moderating_group_ids &= topic.secure_group_ids if topic.secure_group_ids
        config.allowed_group_ids.push(*category_moderating_group_ids)
      end

      config.allowed_group_ids.uniq!

      config
    elsif post_id = channel_name[%r{/discourse-presence/translate/(\d+)}, 1]
      post = Post.find(post_id)
      topic = Topic.find(post.topic_id)

      config = PresenceChannel::Config.new
      config.allowed_group_ids = staff_groups
      config.allowed_user_ids = []

      if topic.private_message?
        config.allowed_user_ids += topic.allowed_users.pluck(:id)
        config.allowed_group_ids += topic.allowed_groups.pluck(:group_id)
      elsif secure_group_ids = topic.secure_group_ids
        config.allowed_group_ids += secure_group_ids
      elsif SiteSetting.content_localization_enabled
        config.allowed_group_ids += SiteSetting.content_localization_allowed_groups_map
      end

      if SiteSetting.content_localization_allow_author_localization &&
           post.user.guardian.can_see?(topic)
        config.allowed_user_ids ||= []
        config.allowed_user_ids << post.user_id
      end

      config.allowed_group_ids.uniq!

      config
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
