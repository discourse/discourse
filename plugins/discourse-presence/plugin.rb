# frozen_string_literal: true

# name: discourse-presence
# about: Show which users are replying to a topic, or editing a post
# version: 2.0
# authors: André Pereira, David Taylor, tgxworld
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-presence

enabled_site_setting :presence_enabled
hide_plugin

register_asset "stylesheets/presence.scss"

after_initialize do
  register_presence_channel_prefix("discourse-presence") do |channel_name|
    if topic_id = channel_name[%r{/discourse-presence/reply/(\d+)}, 1]
      topic = Topic.find(topic_id)
      config = PresenceChannel::Config.new

      if topic.private_message?
        config.allowed_user_ids = topic.allowed_users.pluck(:id)
        config.allowed_group_ids =
          topic.allowed_groups.pluck(:group_id) + [::Group::AUTO_GROUPS[:staff]]
      elsif secure_group_ids = topic.secure_group_ids
        config.allowed_group_ids = secure_group_ids + [::Group::AUTO_GROUPS[:admins]]
      else
        # config.public=true would make data available to anon, so use the tl0 group instead
        config.allowed_group_ids = [::Group::AUTO_GROUPS[:trust_level_0]]
      end

      config
    elsif topic_id = channel_name[%r{/discourse-presence/whisper/(\d+)}, 1]
      Topic.find(topic_id) # Just ensure it exists
      PresenceChannel::Config.new(allowed_group_ids: SiteSetting.whispers_allowed_groups_map)
    elsif post_id = channel_name[%r{/discourse-presence/edit/(\d+)}, 1]
      post = Post.find(post_id)
      topic = Topic.find(post.topic_id)

      config = PresenceChannel::Config.new
      config.allowed_group_ids = [::Group::AUTO_GROUPS[:staff]]

      # Locked posts are staff only
      next config if post.locked?

      # Whispers posts are for allowed whisper groups
      if post.whisper?
        config.allowed_group_ids += SiteSetting.whispers_allowed_groups_map
        next config
      end

      config.allowed_user_ids = [post.user_id]

      if topic.private_message? && post.wiki
        # Ignore trust level and just publish to all allowed groups since
        # trying to figure out which users in the allowed groups have
        # the necessary trust levels can lead to a large array of user ids
        # if the groups are big.
        config.allowed_user_ids += topic.allowed_users.pluck(:id)
        config.allowed_group_ids += topic.allowed_groups.pluck(:id)
      elsif post.wiki
        config.allowed_group_ids += SiteSetting.edit_wiki_post_allowed_groups_map
      end

      if !topic.private_message? && SiteSetting.edit_all_post_groups_map.present?
        config.allowed_group_ids += SiteSetting.edit_all_post_groups_map
      end

      if SiteSetting.enable_category_group_moderation? && topic.category
        config.allowed_group_ids.push(*topic.category.moderating_groups.pluck(:id))
      end

      config
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
