# frozen_string_literal: true

# name: chat
# about: Chat inside Discourse
# version: 0.4
# authors: Kane York, Mark VanLandingham, Martin Brennan, Joffrey Jaffeux
# url: https://github.com/discourse/discourse/tree/main/plugins/chat
# transpile_js: true

enabled_site_setting :chat_enabled

register_asset "stylesheets/colors.scss", :color_definitions
register_asset "stylesheets/mixins/index.scss"
register_asset "stylesheets/common/index.scss"
register_asset "stylesheets/desktop/index.scss", :desktop
register_asset "stylesheets/mobile/index.scss", :mobile

register_svg_icon "comments"
register_svg_icon "comment-slash"
register_svg_icon "lock"
register_svg_icon "file-audio"
register_svg_icon "file-video"
register_svg_icon "file-image"

# route: /admin/plugins/chat
add_admin_route "chat.admin.title", "chat"

GlobalSetting.add_default(:allow_unsecure_chat_uploads, false)

module ::Chat
  PLUGIN_NAME = "chat"
end

require_relative "lib/chat/engine"
require_relative "lib/chat/types/array"

after_initialize do
  register_seedfu_fixtures(Rails.root.join("plugins", "chat", "db", "fixtures"))

  UserNotifications.append_view_path(File.expand_path("../app/views", __FILE__))

  register_category_custom_field_type(Chat::HAS_CHAT_ENABLED, :boolean)

  UserUpdater::OPTION_ATTR.push(:chat_enabled)
  UserUpdater::OPTION_ATTR.push(:only_chat_push_notifications)
  UserUpdater::OPTION_ATTR.push(:chat_sound)
  UserUpdater::OPTION_ATTR.push(:ignore_channel_wide_mention)
  UserUpdater::OPTION_ATTR.push(:chat_email_frequency)
  UserUpdater::OPTION_ATTR.push(:chat_header_indicator_preference)

  register_reviewable_type Chat::ReviewableMessage

  reloadable_patch do |plugin|
    ReviewableScore.add_new_types([:needs_review])

    Site.preloaded_category_custom_fields << Chat::HAS_CHAT_ENABLED

    Guardian.prepend Chat::GuardianExtensions
    UserNotifications.prepend Chat::UserNotificationsExtension
    UserOption.prepend Chat::UserOptionExtension
    Category.prepend Chat::CategoryExtension
    Reviewable.prepend Chat::ReviewableExtension
    Bookmark.prepend Chat::BookmarkExtension
    User.prepend Chat::UserExtension
    Jobs::UserEmail.prepend Chat::UserEmailExtension
    Plugin::Instance.prepend Chat::PluginInstanceExtension
    Jobs::ExportCsvFile.class_eval { prepend Chat::MessagesExporter }
  end

  if Oneboxer.respond_to?(:register_local_handler)
    Oneboxer.register_local_handler("chat/chat") do |url, route|
      if route[:message_id].present?
        message = Chat::Message.find_by(id: route[:message_id])
        next if !message

        chat_channel = message.chat_channel
        user = message.user
        next if !chat_channel || !user
      else
        chat_channel = Chat::Channel.find_by(id: route[:channel_id])
        next if !chat_channel
      end

      next if !Guardian.new.can_preview_chat_channel?(chat_channel)

      name = (chat_channel.name if chat_channel.name.present?)

      users =
        chat_channel
          .user_chat_channel_memberships
          .includes(:user)
          .where(user: User.activated.not_suspended.not_staged)
          .limit(10)
          .map do |membership|
            {
              username: membership.user.username,
              avatar_url: membership.user.avatar_template_url.gsub("{size}", "60"),
            }
          end

      remaining_user_count_str =
        if chat_channel.user_count > users.size
          I18n.t("chat.onebox.and_x_others", count: chat_channel.user_count - users.size)
        end

      args = {
        url: url,
        channel_id: chat_channel.id,
        channel_name: name,
        description: chat_channel.description,
        user_count_str: I18n.t("chat.onebox.x_members", count: chat_channel.user_count),
        users: users,
        remaining_user_count_str: remaining_user_count_str,
        is_category: chat_channel.chatable_type == "Category",
        color: chat_channel.chatable_type == "Category" ? chat_channel.chatable.color : nil,
      }

      if message.present?
        args[:message_id] = message.id
        args[:username] = message.user.username
        args[:avatar_url] = message.user.avatar_template_url.gsub("{size}", "20")
        args[:cooked] = message.cooked
        args[:created_at] = message.created_at
        args[:created_at_str] = message.created_at.iso8601
      end

      Mustache.render(Chat.onebox_template, args)
    end
  end

  if InlineOneboxer.respond_to?(:register_local_handler)
    InlineOneboxer.register_local_handler("chat/chat") do |url, route|
      if route[:message_id].present?
        message = Chat::Message.find_by(id: route[:message_id])
        next if !message

        chat_channel = message.chat_channel
        user = message.user
        next if !chat_channel || !user

        title =
          I18n.t(
            "chat.onebox.inline_to_message",
            message_id: message.id,
            chat_channel: chat_channel.name,
            username: user.username,
          )
      else
        chat_channel = Chat::Channel.find_by(id: route[:channel_id])
        next if !chat_channel

        title =
          if chat_channel.name.present?
            I18n.t("chat.onebox.inline_to_channel", chat_channel: chat_channel.name)
          end
      end

      next if !Guardian.new.can_preview_chat_channel?(chat_channel)

      { url: url, title: title }
    end
  end

  if respond_to?(:register_upload_in_use)
    register_upload_in_use do |upload|
      Chat::Message.where(
        "message LIKE ? OR message LIKE ?",
        "%#{upload.sha1}%",
        "%#{upload.base62_sha1}%",
      ).exists? ||
        Chat::Draft.where(
          "data LIKE ? OR data LIKE ?",
          "%#{upload.sha1}%",
          "%#{upload.base62_sha1}%",
        ).exists?
    end
  end

  add_to_serializer(:user_card, :can_chat_user) do
    return false if !SiteSetting.chat_enabled
    return false if scope.user.blank?

    scope.user.id != object.id && scope.can_chat? && Guardian.new(object).can_chat?
  end

  add_to_serializer(
    :current_user,
    :can_chat,
    include_condition: -> do
      return @can_chat if defined?(@can_chat)
      @can_chat = SiteSetting.chat_enabled && scope.can_chat?
    end,
  ) { true }

  add_to_serializer(
    :current_user,
    :has_chat_enabled,
    include_condition: -> do
      return @has_chat_enabled if defined?(@has_chat_enabled)
      @has_chat_enabled = include_can_chat? && object.user_option.chat_enabled
    end,
  ) { true }

  add_to_serializer(
    :current_user,
    :chat_sound,
    include_condition: -> { include_has_chat_enabled? && object.user_option.chat_sound },
  ) { object.user_option.chat_sound }

  add_to_serializer(
    :current_user,
    :needs_channel_retention_reminder,
    include_condition: -> do
      include_has_chat_enabled? && object.staff? &&
        !object.user_option.dismissed_channel_retention_reminder &&
        !SiteSetting.chat_channel_retention_days.zero?
    end,
  ) { true }

  add_to_serializer(
    :current_user,
    :needs_dm_retention_reminder,
    include_condition: -> do
      include_has_chat_enabled? && !object.user_option.dismissed_dm_retention_reminder &&
        !SiteSetting.chat_dm_retention_days.zero?
    end,
  ) { true }

  add_to_serializer(:current_user, :has_joinable_public_channels) do
    Chat::ChannelFetcher.secured_public_channel_search(
      self.scope,
      following: false,
      limit: 1,
      status: :open,
    ).exists?
  end

  add_to_serializer(:current_user, :chat_channels) do
    structured = Chat::ChannelFetcher.structured(self.scope)

    if SiteSetting.enable_experimental_chat_threaded_discussions
      structured[:unread_thread_overview] = ::Chat::TrackingStateReportQuery.call(
        guardian: self.scope,
        channel_ids: structured[:public_channels].map(&:id),
        include_threads: true,
        include_read: false,
        include_last_reply_details: true,
      ).thread_unread_overview_by_channel
    end

    Chat::ChannelIndexSerializer.new(structured, scope: self.scope, root: false).as_json
  end

  add_to_serializer(
    :current_user,
    :chat_drafts,
    include_condition: -> { include_has_chat_enabled? },
  ) do
    Chat::Draft
      .where(user_id: object.id)
      .order(updated_at: :desc)
      .limit(20)
      .pluck(:chat_channel_id, :data)
      .map { |row| { channel_id: row[0], data: row[1] } }
  end

  add_to_serializer(:user_option, :chat_enabled) { object.chat_enabled }

  add_to_serializer(
    :user_option,
    :chat_sound,
    include_condition: -> { !object.chat_sound.blank? },
  ) { object.chat_sound }

  add_to_serializer(:user_option, :only_chat_push_notifications) do
    object.only_chat_push_notifications
  end

  add_to_serializer(:user_option, :ignore_channel_wide_mention) do
    object.ignore_channel_wide_mention
  end

  add_to_serializer(:user_option, :chat_email_frequency) { object.chat_email_frequency }

  add_to_serializer(:user_option, :chat_header_indicator_preference) do
    object.chat_header_indicator_preference
  end

  add_to_serializer(:current_user_option, :chat_header_indicator_preference) do
    object.chat_header_indicator_preference
  end

  RETENTION_SETTINGS_TO_USER_OPTION_FIELDS = {
    chat_channel_retention_days: :dismissed_channel_retention_reminder,
    chat_dm_retention_days: :dismissed_dm_retention_reminder,
  }
  on(:site_setting_changed) do |name, old_value, new_value|
    user_option_field = RETENTION_SETTINGS_TO_USER_OPTION_FIELDS[name.to_sym]
    begin
      if user_option_field && old_value != new_value && !new_value.zero?
        UserOption.where(user_option_field => true).update_all(user_option_field => false)
      end
    rescue => e
      Rails.logger.warn(
        "Error updating user_options fields after chat retention settings changed: #{e}",
      )
    end

    if name == :secure_uploads && old_value == false && new_value == true
      Chat::SecureUploadsCompatibility.update_settings
    end

    if name == :chat_allowed_groups
      Jobs.enqueue(
        Jobs::Chat::AutoRemoveMembershipHandleChatAllowedGroupsChange,
        new_allowed_groups: new_value,
      )
    end
  end

  on(:post_alerter_after_save_post) do |post, new_record, notified|
    next if !new_record
    Chat::PostNotificationHandler.new(post, notified).handle
  end

  on(:group_destroyed) do |group, user_ids|
    Jobs.enqueue(
      Jobs::Chat::AutoRemoveMembershipHandleDestroyedGroup,
      destroyed_group_user_ids: user_ids,
    )
  end

  register_presence_channel_prefix("chat") do |channel_name|
    next nil unless channel_name == "/chat/online"
    config = PresenceChannel::Config.new
    config.allowed_group_ids = Chat.allowed_group_ids
    config
  end

  register_presence_channel_prefix("chat-reply") do |channel_name|
    if chat_channel_id = channel_name[%r{/chat-reply/(\d+)}, 1]
      chat_channel = Chat::Channel.find(chat_channel_id)

      PresenceChannel::Config.new.tap do |config|
        config.allowed_group_ids = chat_channel.allowed_group_ids
        config.allowed_user_ids = chat_channel.allowed_user_ids
        config.public = !chat_channel.read_restricted?
      end
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  register_presence_channel_prefix("chat-user") do |channel_name|
    if user_id = channel_name[%r{/chat-user/(chat|core)/(\d+)}, 2]
      user = User.find(user_id)
      config = PresenceChannel::Config.new
      config.allowed_user_ids = [user.id]
      config
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  CHAT_NOTIFICATION_TYPES = [Notification.types[:chat_mention], Notification.types[:chat_message]]
  register_push_notification_filter do |user, payload|
    if user.user_option.only_chat_push_notifications && user.user_option.chat_enabled
      CHAT_NOTIFICATION_TYPES.include?(payload[:notification_type])
    else
      true
    end
  end

  on(:user_seen) do |user|
    if user.last_seen_at == user.first_seen_at
      Chat::Channel
        .where(auto_join_users: true)
        .each do |channel|
          Chat::ChannelMembershipManager.new(channel).enforce_automatic_user_membership(user)
        end
    end
  end

  on(:user_confirmed_email) do |user|
    if user.active?
      Chat::Channel
        .where(auto_join_users: true)
        .each do |channel|
          Chat::ChannelMembershipManager.new(channel).enforce_automatic_user_membership(user)
        end
    end
  end

  on(:user_added_to_group) do |user, group|
    channels_to_add =
      Chat::Channel
        .distinct
        .where(auto_join_users: true, chatable_type: "Category")
        .joins(
          "INNER JOIN category_groups ON category_groups.category_id = chat_channels.chatable_id",
        )
        .where(category_groups: { group_id: group.id })

    channels_to_add.each do |channel|
      Chat::ChannelMembershipManager.new(channel).enforce_automatic_user_membership(user)
    end
  end

  on(:user_removed_from_group) do |user, group|
    Jobs.enqueue(Jobs::Chat::AutoRemoveMembershipHandleUserRemovedFromGroup, user_id: user.id)
  end

  on(:category_updated) do |category|
    # TODO(roman): remove early return after 2.9 release.
    # There's a bug on core where this event is triggered with an `#update` result (true/false)
    if category.is_a?(Category) && category_channel = Chat::Channel.find_by(chatable: category)
      if category_channel.auto_join_users
        Chat::ChannelMembershipManager.new(category_channel).enforce_automatic_channel_memberships
      end

      Jobs.enqueue(Jobs::Chat::AutoRemoveMembershipHandleCategoryUpdated, category_id: category.id)
    end
  end

  Discourse::Application.routes.append do
    mount ::Chat::Engine, at: "/chat"

    get "/admin/plugins/chat" => "chat/admin/incoming_webhooks#index",
        :constraints => StaffConstraint.new
    post "/admin/plugins/chat/hooks" => "chat/admin/incoming_webhooks#create",
         :constraints => StaffConstraint.new
    put "/admin/plugins/chat/hooks/:incoming_chat_webhook_id" =>
          "chat/admin/incoming_webhooks#update",
        :constraints => StaffConstraint.new
    delete "/admin/plugins/chat/hooks/:incoming_chat_webhook_id" =>
             "chat/admin/incoming_webhooks#destroy",
           :constraints => StaffConstraint.new
    get "u/:username/preferences/chat" => "users#preferences",
        :constraints => {
          username: RouteFormat.username,
        }
  end

  if defined?(DiscourseAutomation)
    add_automation_scriptable("send_chat_message") do
      field :chat_channel_id, component: :text, required: true
      field :message, component: :message, required: true, accepts_placeholders: true
      field :sender, component: :user

      placeholder :channel_name

      triggerables [:recurring]

      script do |context, fields, automation|
        sender = User.find_by(username: fields.dig("sender", "value")) || Discourse.system_user
        channel = Chat::Channel.find_by(id: fields.dig("chat_channel_id", "value"))

        placeholders = { channel_name: channel.title(sender) }.merge(context["placeholders"] || {})

        creator =
          Chat::MessageCreator.create(
            chat_channel: channel,
            user: sender,
            content: utils.apply_placeholders(fields.dig("message", "value"), placeholders),
          )

        if creator.failed?
          Rails.logger.warn "[discourse-automation] Chat message failed to send, error was: #{creator.error}"
        end
      end
    end
  end

  add_api_key_scope(
    :chat,
    { create_message: { actions: %w[chat/chat#create_message], params: %i[chat_channel_id] } },
  )

  # Dark mode email styles
  Email::Styles.register_plugin_style do |fragment|
    fragment.css(".chat-summary-header").each { |element| element[:dm] = "header" }
    fragment.css(".chat-summary-content").each { |element| element[:dm] = "body" }
  end

  register_email_unsubscriber("chat_summary", EmailControllerHelper::ChatSummaryUnsubscriber)

  register_about_stat_group("chat_messages", show_in_ui: true) { Chat::Statistics.about_messages }

  register_about_stat_group("chat_channels") { Chat::Statistics.about_channels }

  register_about_stat_group("chat_users") { Chat::Statistics.about_users }

  # Make sure to update spec/system/hashtag_autocomplete_spec.rb when changing this.
  register_hashtag_data_source(Chat::ChannelHashtagDataSource)
  register_hashtag_type_priority_for_context("channel", "chat-composer", 200)
  register_hashtag_type_priority_for_context("category", "chat-composer", 100)
  register_hashtag_type_priority_for_context("tag", "chat-composer", 50)
  register_hashtag_type_priority_for_context("channel", "topic-composer", 10)

  Site.markdown_additional_options["chat"] = {
    limited_pretty_text_features: Chat::Message::MARKDOWN_FEATURES,
    limited_pretty_text_markdown_rules: Chat::Message::MARKDOWN_IT_RULES,
    hashtag_configurations: HashtagAutocompleteService.contexts_with_ordered_types,
  }

  register_user_destroyer_on_content_deletion_callback(
    Proc.new { |user| Jobs.enqueue(Jobs::Chat::DeleteUserMessages, user_id: user.id) },
  )

  register_bookmarkable(Chat::MessageBookmarkable)
end

if Rails.env == "test"
  Dir[Rails.root.join("plugins/chat/spec/support/**/*.rb")].each { |f| require f }
end
