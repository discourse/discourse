# frozen_string_literal: true

# name: chat
# about: Adds chat functionality to your site so it can natively support both long-form and short-form communication needs of your online community.
# meta_topic_id: 230881
# version: 0.4
# authors: Kane York, Mark VanLandingham, Martin Brennan, Joffrey Jaffeux
# url: https://github.com/discourse/discourse/tree/main/plugins/chat
# meta_topic_id: 230881

enabled_site_setting :chat_enabled

register_asset "stylesheets/colors.scss", :color_definitions
register_asset "stylesheets/mixins/index.scss"
register_asset "stylesheets/common/index.scss"
register_asset "stylesheets/desktop/index.scss", :desktop
register_asset "stylesheets/mobile/index.scss", :mobile

register_svg_icon "comments"
register_svg_icon "comment-slash"
register_svg_icon "comment-dots"
register_svg_icon "lock"
register_svg_icon "clipboard"
register_svg_icon "file-audio"
register_svg_icon "file-video"
register_svg_icon "file-image"
register_svg_icon "circle-stop"

# route: /admin/plugins/chat
add_admin_route "chat.admin.title", "chat", use_new_show_route: true

GlobalSetting.add_default(:allow_unsecure_chat_uploads, false)

module ::Chat
  PLUGIN_NAME = "chat"
  RETENTION_SETTINGS_TO_USER_OPTION_FIELDS = {
    chat_channel_retention_days: :dismissed_channel_retention_reminder,
    chat_dm_retention_days: :dismissed_dm_retention_reminder,
  }
  PRESENCE_REGEXP = %r{^/chat-reply/(\d+)(?:/thread/(\d+))?$}
end

require_relative "lib/chat/engine"

after_initialize do
  register_seedfu_fixtures(Rails.root.join("plugins", "chat", "db", "fixtures"))

  UserNotifications.append_view_path(File.expand_path("../app/views", __FILE__))

  register_category_custom_field_type(Chat::HAS_CHAT_ENABLED, :boolean)

  register_user_custom_field_type(Chat::LAST_CHAT_CHANNEL_ID, :integer)
  DiscoursePluginRegistry.serialized_current_user_fields << Chat::LAST_CHAT_CHANNEL_ID
  DiscoursePluginRegistry.register_flag_applies_to_type("Chat::Message", self)

  UserUpdater::OPTION_ATTR.push(:chat_enabled)
  UserUpdater::OPTION_ATTR.push(:only_chat_push_notifications)
  UserUpdater::OPTION_ATTR.push(:chat_sound)
  UserUpdater::OPTION_ATTR.push(:ignore_channel_wide_mention)
  UserUpdater::OPTION_ATTR.push(:show_thread_title_prompts)
  UserUpdater::OPTION_ATTR.push(:chat_email_frequency)
  UserUpdater::OPTION_ATTR.push(:chat_header_indicator_preference)
  UserUpdater::OPTION_ATTR.push(:chat_separate_sidebar_mode)

  register_reviewable_type Chat::ReviewableMessage

  reloadable_patch do |plugin|
    Site.preloaded_category_custom_fields << Chat::HAS_CHAT_ENABLED

    Guardian.prepend Chat::GuardianExtensions
    UserNotifications.prepend Chat::UserNotificationsExtension
    Notifications::ConsolidationPlan.prepend Chat::NotificationConsolidationExtension
    UserOption.prepend Chat::UserOptionExtension
    Category.prepend Chat::CategoryExtension
    Reviewable.prepend Chat::ReviewableExtension
    Bookmark.prepend Chat::BookmarkExtension
    User.prepend Chat::UserExtension
    Group.prepend Chat::GroupExtension
    Plugin::Instance.prepend Chat::PluginInstanceExtension
    Jobs::ExportCsvFile.prepend Chat::MessagesExporter
    WebHook.prepend Chat::OutgoingWebHookExtension
  end

  if Oneboxer.respond_to?(:register_local_handler)
    Oneboxer.register_local_handler("chat/chat") do |url, route|
      Chat::OneboxHandler.handle(url, route)
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
    return false if !scope.user.user_option.chat_enabled || !object.user_option.chat_enabled

    scope.can_direct_message? && Guardian.new(object).can_chat?
  end

  add_to_serializer(:hidden_profile, :can_chat_user) do
    return false if !SiteSetting.chat_enabled
    return false if scope.user.blank?
    return false if !scope.user.user_option.chat_enabled || !object.user_option.chat_enabled

    scope.can_direct_message? && Guardian.new(object).can_chat?
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
    :can_direct_message,
    include_condition: -> do
      return @can_direct_message if defined?(@can_direct_message)
      @can_direct_message = include_has_chat_enabled? && scope.can_direct_message?
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

  add_to_serializer(
    :current_user,
    :chat_drafts,
    include_condition: -> { include_has_chat_enabled? },
  ) do
    Chat::Draft
      .where(user_id: object.id)
      .order(updated_at: :desc)
      .limit(20)
      .pluck(:chat_channel_id, :data, :thread_id)
      .map { |row| { channel_id: row[0], data: row[1], thread_id: row[2] } }
  end

  add_to_serializer(
    :user_notification_total,
    :chat_notifications,
    include_condition: -> do
      return @has_chat_enabled if defined?(@has_chat_enabled)
      @has_chat_enabled =
        SiteSetting.chat_enabled && scope.can_chat? && object.user_option.chat_enabled
    end,
  ) { Chat::ChannelFetcher.unreads_total(self.scope) }

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

  add_to_serializer(:user_option, :show_thread_title_prompts) { object.show_thread_title_prompts }

  add_to_serializer(:current_user_option, :show_thread_title_prompts) do
    object.show_thread_title_prompts
  end

  add_to_serializer(:user_option, :chat_email_frequency) { object.chat_email_frequency }

  add_to_serializer(:user_option, :chat_header_indicator_preference) do
    object.chat_header_indicator_preference
  end

  add_to_serializer(:current_user_option, :chat_header_indicator_preference) do
    object.chat_header_indicator_preference
  end

  add_to_serializer(:user_option, :chat_separate_sidebar_mode) { object.chat_separate_sidebar_mode }

  add_to_serializer(:current_user_option, :chat_separate_sidebar_mode) do
    object.chat_separate_sidebar_mode
  end

  on(:site_setting_changed) do |name, old_value, new_value|
    user_option_field = Chat::RETENTION_SETTINGS_TO_USER_OPTION_FIELDS[name.to_sym]
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
      Jobs.enqueue(Jobs::Chat::AutoJoinUsers, event: "chat_allowed_groups_changed")
    end
  end

  on(:post_alerter_after_save_post) do |post, new_record, notified|
    next if !new_record
    Chat::PostNotificationHandler.new(post, notified).handle
  end

  on(:group_destroyed) do |group, _user_ids|
    Chat::AutoLeaveChannels.call(params: { group_id: group.id, event: :group_destroyed })
  end

  register_presence_channel_prefix("chat") do |channel_name|
    next if channel_name != "/chat/online"
    PresenceChannel::Config.new.tap { |config| config.allowed_group_ids = Chat.allowed_group_ids }
  end

  register_presence_channel_prefix("chat-reply") do |channel_name|
    channel_id, thread_id = Chat::PRESENCE_REGEXP.match(channel_name)&.captures

    next if channel_id.blank?

    chat_channel =
      if thread_id.present?
        Chat::Thread.find_by(id: thread_id, channel_id:)&.channel
      else
        Chat::Channel.find_by(id: channel_id)
      end

    next if chat_channel.nil?

    PresenceChannel::Config.new.tap do |config|
      config.allowed_group_ids = chat_channel.allowed_group_ids
      config.allowed_user_ids = chat_channel.allowed_user_ids
      config.public = !chat_channel.read_restricted?
    end
  end

  register_push_notification_filter do |user, payload|
    if user.user_option.only_chat_push_notifications && user.user_option.chat_enabled
      payload[:notification_type].in?(::Notification.types.values_at(:chat_mention, :chat_message))
    else
      true
    end
  end

  on(:user_seen) do |user|
    if user.last_seen_at == user.first_seen_at
      Chat::AutoJoinChannels.call(params: { user_id: user.id })
    end
  end

  on(:user_confirmed_email) do |user|
    Chat::AutoJoinChannels.call(params: { user_id: user.id }) if user.active?
  end

  on(:user_added_to_group) do |user, _group|
    Chat::AutoJoinChannels.call(params: { user_id: user.id })
  end

  on(:user_removed_from_group) do |user, _group|
    Chat::AutoLeaveChannels.call(params: { user_id: user.id, event: :user_removed_from_group })
  end

  on(:category_updated) do |category|
    # There's a bug on core where this event is triggered with an `#update` result (true/false)
    next unless category.is_a?(Category)
    next unless category_channel = Chat::Channel.find_by(chatable: category)

    if category_channel.auto_join_users
      Chat::AutoJoinChannels.call(params: { category_id: category.id })
    end
    Chat::AutoLeaveChannels.call(params: { category_id: category.id, event: :category_updated })
  end

  # outgoing webhook events
  %i[
    chat_message_created
    chat_message_edited
    chat_message_trashed
    chat_message_restored
  ].each do |chat_message_event|
    on(chat_message_event) do |message, channel, user|
      guardian = Guardian.new(user)

      payload = {
        message: Chat::MessageSerializer.new(message, { scope: guardian, root: false }).as_json,
        channel:
          Chat::ChannelSerializer.new(
            channel,
            { scope: guardian, membership: channel.membership_for(user), root: false },
          ).as_json,
      }

      category_id = channel.chatable_type == "Category" ? channel.chatable_id : nil

      WebHook.enqueue_chat_message_hooks(
        chat_message_event,
        payload.to_json,
        category_id: category_id,
      )
    end
  end

  Discourse::Application.routes.append do
    mount ::Chat::Engine, at: "/chat"

    get "/admin/plugins/chat/hooks" => "chat/admin/incoming_webhooks#index",
        :constraints => StaffConstraint.new
    post "/admin/plugins/chat/hooks" => "chat/admin/incoming_webhooks#create",
         :constraints => StaffConstraint.new
    put "/admin/plugins/chat/hooks/:incoming_chat_webhook_id" =>
          "chat/admin/incoming_webhooks#update",
        :constraints => StaffConstraint.new
    get "/admin/plugins/chat/hooks/new" => "chat/admin/incoming_webhooks#new",
        :constraints => StaffConstraint.new
    get "/admin/plugins/chat/hooks/:incoming_chat_webhook_id/edit" =>
          "chat/admin/incoming_webhooks#edit",
        :constraints => StaffConstraint.new
    delete "/admin/plugins/chat/hooks/:incoming_chat_webhook_id" =>
             "chat/admin/incoming_webhooks#destroy",
           :constraints => StaffConstraint.new
    get "u/:username/preferences/chat" => "users#preferences",
        :constraints => {
          username: RouteFormat.username,
        }
  end

  add_automation_scriptable("send_chat_message") do
    field :chat_channel_id, component: :text, required: true
    field :message, component: :message, required: true, accepts_placeholders: true
    field :sender, component: :user

    placeholder :channel_name
    placeholder :post_quote, triggerable: :post_created_edited

    triggerables %i[recurring topic_tags_changed post_created_edited]

    script do |context, fields, automation|
      sender = User.find_by(username: fields.dig("sender", "value")) || Discourse.system_user
      channel = Chat::Channel.find_by(id: fields.dig("chat_channel_id", "value"))
      placeholders = { channel_name: channel.title(sender) }.merge(context["placeholders"] || {})

      if context["kind"] == "post_created_edited"
        placeholders[:post_quote] = utils.build_quote(context["post"])
      end

      creator =
        ::Chat::CreateMessage.call(
          guardian: sender.guardian,
          params: {
            chat_channel_id: channel.id,
            message: utils.apply_placeholders(fields.dig("message", "value"), placeholders),
          },
        )

      if creator.failure?
        Rails.logger.warn "[discourse-automation] Chat message failed to send:\n#{creator.inspect_steps}"
      end
    end
  end

  add_api_key_scope(
    :chat,
    {
      create_message: {
        actions: %w[chat/api/channel_messages#create],
        params: %i[chat_channel_id],
      },
    },
  )

  # Dark mode email styles
  Email::Styles.register_plugin_style do |fragment|
    fragment.css(".chat-summary-header").each { |element| element[:dm] = "header" }
    fragment.css(".chat-summary-content").each { |element| element[:dm] = "body" }
  end

  register_email_unsubscriber("chat_summary", EmailControllerHelper::ChatSummaryUnsubscriber)

  register_stat("chat_messages", expose_via_api: true) { Chat::Statistics.about_messages }
  register_stat("chat_users", expose_via_api: true) { Chat::Statistics.about_users }
  register_stat("chat_channels", expose_via_api: true) { Chat::Statistics.about_channels }

  register_stat("chat_channel_messages") { Chat::Statistics.channel_messages }
  register_stat("chat_direct_messages") { Chat::Statistics.direct_messages }
  register_stat("chat_open_channels_with_threads_enabled") do
    Chat::Statistics.open_channels_with_threads_enabled
  end
  register_stat("chat_threaded_messages") { Chat::Statistics.threaded_messages }

  # Make sure to update spec/system/hashtag_autocomplete_spec.rb when changing this.
  register_hashtag_data_source(Chat::ChannelHashtagDataSource)
  register_hashtag_type_priority_for_context("channel", "chat-composer", 200)
  register_hashtag_type_priority_for_context("category", "chat-composer", 100)
  register_hashtag_type_priority_for_context("tag", "chat-composer", 50)
  register_hashtag_type_priority_for_context("channel", "topic-composer", 10)

  register_post_stripper do |nokogiri_fragment|
    nokogiri_fragment.css(".chat-transcript .mention").remove
  end

  Site.markdown_additional_options["chat"] = {
    limited_pretty_text_features: Chat::Message::MARKDOWN_FEATURES,
    limited_pretty_text_markdown_rules: Chat::Message::MARKDOWN_IT_RULES,
    hashtag_configurations: HashtagAutocompleteService.contexts_with_ordered_types,
  }

  register_user_destroyer_on_content_deletion_callback(
    Proc.new { |user| Jobs.enqueue(Jobs::Chat::DeleteUserMessages, user_id: user.id) },
  )

  register_notification_consolidation_plan(
    Chat::NotificationConsolidationExtension.watched_thread_message_plan,
  )

  register_bookmarkable(Chat::MessageBookmarkable)

  # When we eventually allow secure_uploads in chat, this will need to be
  # removed. Depending on the channel, uploads may end up being secure.
  UploadSecurity.register_custom_public_type("chat-composer")
end

if Rails.env == "test"
  Dir[Rails.root.join("plugins/chat/spec/support/**/*.rb")].each { |f| require f }
end
