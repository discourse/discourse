# frozen_string_literal: true

# name: chat
# about: Chat inside Discourse
# version: 0.4
# authors: Kane York, Mark VanLandingham, Martin Brennan, Joffrey Jaffeux
# url: https://github.com/discourse/discourse/tree/main/plugins/chat
# transpile_js: true

enabled_site_setting :chat_enabled

register_asset "stylesheets/mixins/chat-scrollbar.scss"
register_asset "stylesheets/common/core-extensions.scss"
register_asset "stylesheets/common/chat-emoji-picker.scss"
register_asset "stylesheets/common/chat-channel-card.scss"
register_asset "stylesheets/common/create-channel-modal.scss"
register_asset "stylesheets/common/dc-filter-input.scss"
register_asset "stylesheets/common/common.scss"
register_asset "stylesheets/common/chat-browse.scss"
register_asset "stylesheets/common/chat-drawer.scss"
register_asset "stylesheets/common/chat-index.scss"
register_asset "stylesheets/mobile/chat-index.scss", :mobile
register_asset "stylesheets/desktop/chat-index-full-page.scss", :desktop
register_asset "stylesheets/desktop/chat-index-drawer.scss", :desktop
register_asset "stylesheets/common/chat-channel-preview-card.scss"
register_asset "stylesheets/common/chat-channel-info.scss"
register_asset "stylesheets/common/chat-draft-channel.scss"
register_asset "stylesheets/common/chat-tabs.scss"
register_asset "stylesheets/common/chat-form.scss"
register_asset "stylesheets/common/d-progress-bar.scss"
register_asset "stylesheets/common/incoming-chat-webhooks.scss"
register_asset "stylesheets/mobile/chat-message.scss", :mobile
register_asset "stylesheets/desktop/chat-message.scss", :desktop
register_asset "stylesheets/common/chat-channel-title.scss"
register_asset "stylesheets/desktop/chat-channel-title.scss", :desktop
register_asset "stylesheets/common/full-page-chat-header.scss"
register_asset "stylesheets/common/chat-reply.scss"
register_asset "stylesheets/common/chat-message.scss"
register_asset "stylesheets/common/chat-message-left-gutter.scss"
register_asset "stylesheets/common/chat-message-info.scss"
register_asset "stylesheets/common/chat-composer-inline-button.scss"
register_asset "stylesheets/common/chat-replying-indicator.scss"
register_asset "stylesheets/common/chat-composer.scss"
register_asset "stylesheets/desktop/chat-composer.scss", :desktop
register_asset "stylesheets/mobile/chat-composer.scss", :mobile
register_asset "stylesheets/common/direct-message-creator.scss"
register_asset "stylesheets/common/chat-message-collapser.scss"
register_asset "stylesheets/common/chat-message-images.scss"
register_asset "stylesheets/common/chat-transcript.scss"
register_asset "stylesheets/common/chat-composer-dropdown.scss"
register_asset "stylesheets/common/chat-retention-reminder.scss"
register_asset "stylesheets/common/chat-composer-uploads.scss"
register_asset "stylesheets/desktop/chat-composer-uploads.scss", :desktop
register_asset "stylesheets/common/chat-composer-upload.scss"
register_asset "stylesheets/common/chat-selection-manager.scss"
register_asset "stylesheets/mobile/chat-selection-manager.scss", :mobile
register_asset "stylesheets/common/chat-channel-selector-modal.scss"
register_asset "stylesheets/mobile/mobile.scss", :mobile
register_asset "stylesheets/desktop/desktop.scss", :desktop
register_asset "stylesheets/sidebar-extensions.scss"
register_asset "stylesheets/desktop/sidebar-extensions.scss", :desktop
register_asset "stylesheets/common/chat-message-actions.scss"
register_asset "stylesheets/desktop/chat-message-actions.scss", :desktop
register_asset "stylesheets/mobile/chat-message-actions.scss", :mobile
register_asset "stylesheets/common/chat-message-separator.scss"
register_asset "stylesheets/common/chat-onebox.scss"
register_asset "stylesheets/common/chat-skeleton.scss"
register_asset "stylesheets/colors.scss", :color_definitions
register_asset "stylesheets/common/reviewable-chat-message.scss"
register_asset "stylesheets/common/chat-mention-warnings.scss"
register_asset "stylesheets/common/chat-channel-settings-saved-indicator.scss"
register_asset "stylesheets/common/chat-thread.scss"
register_asset "stylesheets/common/chat-side-panel.scss"

register_svg_icon "comments"
register_svg_icon "comment-slash"
register_svg_icon "hashtag"
register_svg_icon "lock"

register_svg_icon "file-audio"
register_svg_icon "file-video"
register_svg_icon "file-image"

# route: /admin/plugins/chat
add_admin_route "chat.admin.title", "chat"

# Site setting validators must be loaded before initialize
require_relative "lib/validators/chat_default_channel_validator.rb"
require_relative "lib/validators/chat_allow_uploads_validator.rb"
require_relative "lib/validators/direct_message_enabled_groups_validator.rb"
require_relative "app/core_ext/plugin_instance.rb"

GlobalSetting.add_default(:allow_unsecure_chat_uploads, false)

after_initialize do
  # Namespace for classes and modules parts of chat plugin
  module ::Chat
    PLUGIN_NAME = "chat"
    HAS_CHAT_ENABLED = "has_chat_enabled"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace Chat
    end

    def self.allowed_group_ids
      SiteSetting.chat_allowed_groups_map
    end

    def self.onebox_template
      @onebox_template ||=
        begin
          path = "#{Rails.root}/plugins/chat/lib/onebox/templates/discourse_chat.mustache"
          File.read(path)
        end
    end
  end

  register_seedfu_fixtures(Rails.root.join("plugins", "chat", "db", "fixtures"))

  load File.expand_path(
         "../app/controllers/admin/admin_incoming_chat_webhooks_controller.rb",
         __FILE__,
       )
  load File.expand_path("../app/helpers/with_service_helper.rb", __FILE__)
  load File.expand_path("../app/controllers/chat_base_controller.rb", __FILE__)
  load File.expand_path("../app/controllers/chat_controller.rb", __FILE__)
  load File.expand_path("../app/controllers/emojis_controller.rb", __FILE__)
  load File.expand_path("../app/controllers/direct_messages_controller.rb", __FILE__)
  load File.expand_path("../app/controllers/incoming_chat_webhooks_controller.rb", __FILE__)
  load File.expand_path("../app/models/concerns/chatable.rb", __FILE__)
  load File.expand_path("../app/models/deleted_chat_user.rb", __FILE__)
  load File.expand_path("../app/models/user_chat_channel_membership.rb", __FILE__)
  load File.expand_path("../app/models/chat_channel.rb", __FILE__)
  load File.expand_path("../app/models/chat_channel_archive.rb", __FILE__)
  load File.expand_path("../app/models/chat_draft.rb", __FILE__)
  load File.expand_path("../app/models/chat_message.rb", __FILE__)
  load File.expand_path("../app/models/chat_message_reaction.rb", __FILE__)
  load File.expand_path("../app/models/chat_message_revision.rb", __FILE__)
  load File.expand_path("../app/models/chat_mention.rb", __FILE__)
  load File.expand_path("../app/models/chat_thread.rb", __FILE__)
  load File.expand_path("../app/models/chat_upload.rb", __FILE__)
  load File.expand_path("../app/models/chat_webhook_event.rb", __FILE__)
  load File.expand_path("../app/models/direct_message_channel.rb", __FILE__)
  load File.expand_path("../app/models/direct_message.rb", __FILE__)
  load File.expand_path("../app/models/direct_message_user.rb", __FILE__)
  load File.expand_path("../app/models/incoming_chat_webhook.rb", __FILE__)
  load File.expand_path("../app/models/reviewable_chat_message.rb", __FILE__)
  load File.expand_path("../app/models/chat_view.rb", __FILE__)
  load File.expand_path("../app/models/category_channel.rb", __FILE__)
  load File.expand_path("../app/serializers/structured_channel_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/chat_webhook_event_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/chat_in_reply_to_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/base_chat_channel_membership_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/user_chat_channel_membership_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/chat_message_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/chat_channel_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/chat_channel_index_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/chat_channel_search_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/chat_thread_original_message_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/chat_thread_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/chat_view_serializer.rb", __FILE__)
  load File.expand_path(
         "../app/serializers/user_with_custom_fields_and_status_serializer.rb",
         __FILE__,
       )
  load File.expand_path("../app/serializers/direct_message_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/incoming_chat_webhook_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/admin_chat_index_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/user_chat_message_bookmark_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/reviewable_chat_message_serializer.rb", __FILE__)
  load File.expand_path("../app/services/base.rb", __FILE__)
  load File.expand_path("../lib/chat_channel_fetcher.rb", __FILE__)
  load File.expand_path("../lib/chat_channel_hashtag_data_source.rb", __FILE__)
  load File.expand_path("../lib/chat_mailer.rb", __FILE__)
  load File.expand_path("../lib/chat_message_creator.rb", __FILE__)
  load File.expand_path("../lib/chat_message_processor.rb", __FILE__)
  load File.expand_path("../lib/chat_message_updater.rb", __FILE__)
  load File.expand_path("../lib/chat_message_rate_limiter.rb", __FILE__)
  load File.expand_path("../lib/chat_message_reactor.rb", __FILE__)
  load File.expand_path("../lib/chat_notifier.rb", __FILE__)
  load File.expand_path("../lib/chat_seeder.rb", __FILE__)
  load File.expand_path("../lib/chat_statistics.rb", __FILE__)
  load File.expand_path("../lib/chat_transcript_service.rb", __FILE__)
  load File.expand_path("../lib/duplicate_message_validator.rb", __FILE__)
  load File.expand_path("../lib/message_mover.rb", __FILE__)
  load File.expand_path("../lib/chat_channel_membership_manager.rb", __FILE__)
  load File.expand_path("../lib/chat_message_bookmarkable.rb", __FILE__)
  load File.expand_path("../lib/chat_channel_archive_service.rb", __FILE__)
  load File.expand_path("../lib/chat_review_queue.rb", __FILE__)
  load File.expand_path("../lib/direct_message_channel_creator.rb", __FILE__)
  load File.expand_path("../lib/guardian_extensions.rb", __FILE__)
  load File.expand_path("../lib/extensions/user_option_extension.rb", __FILE__)
  load File.expand_path("../lib/extensions/user_notifications_extension.rb", __FILE__)
  load File.expand_path("../lib/extensions/user_email_extension.rb", __FILE__)
  load File.expand_path("../lib/extensions/category_extension.rb", __FILE__)
  load File.expand_path("../lib/extensions/user_extension.rb", __FILE__)
  load File.expand_path("../lib/slack_compatibility.rb", __FILE__)
  load File.expand_path("../lib/post_notification_handler.rb", __FILE__)
  load File.expand_path("../lib/secure_uploads_compatibility.rb", __FILE__)
  load File.expand_path("../lib/endpoint.rb", __FILE__)
  load File.expand_path("../lib/steps_inspector.rb", __FILE__)
  load File.expand_path("../app/jobs/regular/auto_manage_channel_memberships.rb", __FILE__)
  load File.expand_path("../app/jobs/regular/auto_join_channel_batch.rb", __FILE__)
  load File.expand_path("../app/jobs/regular/process_chat_message.rb", __FILE__)
  load File.expand_path("../app/jobs/regular/chat_channel_archive.rb", __FILE__)
  load File.expand_path("../app/jobs/regular/chat_channel_delete.rb", __FILE__)
  load File.expand_path("../app/jobs/regular/chat_notify_mentioned.rb", __FILE__)
  load File.expand_path("../app/jobs/regular/chat_notify_watching.rb", __FILE__)
  load File.expand_path("../app/jobs/regular/update_channel_user_count.rb", __FILE__)
  load File.expand_path("../app/jobs/regular/delete_user_messages.rb", __FILE__)
  load File.expand_path("../app/jobs/regular/send_message_notifications.rb", __FILE__)
  load File.expand_path("../app/jobs/scheduled/delete_old_chat_messages.rb", __FILE__)
  load File.expand_path("../app/jobs/scheduled/update_user_counts_for_chat_channels.rb", __FILE__)
  load File.expand_path("../app/jobs/scheduled/email_chat_notifications.rb", __FILE__)
  load File.expand_path("../app/jobs/scheduled/auto_join_users.rb", __FILE__)
  load File.expand_path("../app/jobs/scheduled/chat_periodical_updates.rb", __FILE__)
  load File.expand_path("../app/services/chat_publisher.rb", __FILE__)
  load File.expand_path("../app/services/trash_channel.rb", __FILE__)
  load File.expand_path("../app/services/update_channel.rb", __FILE__)
  load File.expand_path("../app/services/update_channel_status.rb", __FILE__)
  load File.expand_path("../app/services/chat_message_destroyer.rb", __FILE__)
  load File.expand_path("../app/services/update_user_last_read.rb", __FILE__)
  load File.expand_path("../app/controllers/api_controller.rb", __FILE__)
  load File.expand_path("../app/controllers/api/chat_channels_controller.rb", __FILE__)
  load File.expand_path("../app/controllers/api/chat_current_user_channels_controller.rb", __FILE__)
  load File.expand_path(
         "../app/controllers/api/chat_channels_current_user_membership_controller.rb",
         __FILE__,
       )
  load File.expand_path("../app/controllers/api/chat_channels_memberships_controller.rb", __FILE__)
  load File.expand_path(
         "../app/controllers/api/chat_channels_messages_moves_controller.rb",
         __FILE__,
       )
  load File.expand_path("../app/controllers/api/chat_channels_archives_controller.rb", __FILE__)
  load File.expand_path("../app/controllers/api/chat_channels_status_controller.rb", __FILE__)
  load File.expand_path(
         "../app/controllers/api/chat_channels_current_user_notifications_settings_controller.rb",
         __FILE__,
       )
  load File.expand_path("../app/controllers/api/category_chatables_controller.rb", __FILE__)
  load File.expand_path("../app/controllers/api/hints_controller.rb", __FILE__)
  load File.expand_path("../app/controllers/api/chat_channel_threads_controller.rb", __FILE__)
  load File.expand_path("../app/controllers/api/chat_chatables_controller.rb", __FILE__)
  load File.expand_path("../app/queries/chat_channel_memberships_query.rb", __FILE__)

  if Discourse.allow_dev_populate?
    load File.expand_path("../lib/discourse_dev/public_channel.rb", __FILE__)
    load File.expand_path("../lib/discourse_dev/direct_channel.rb", __FILE__)
    load File.expand_path("../lib/discourse_dev/message.rb", __FILE__)
  end

  UserNotifications.append_view_path(File.expand_path("../app/views", __FILE__))

  register_category_custom_field_type(Chat::HAS_CHAT_ENABLED, :boolean)

  UserUpdater::OPTION_ATTR.push(:chat_enabled)
  UserUpdater::OPTION_ATTR.push(:only_chat_push_notifications)
  UserUpdater::OPTION_ATTR.push(:chat_sound)
  UserUpdater::OPTION_ATTR.push(:ignore_channel_wide_mention)
  UserUpdater::OPTION_ATTR.push(:chat_email_frequency)

  register_reviewable_type ReviewableChatMessage

  reloadable_patch do |plugin|
    ReviewableScore.add_new_types([:needs_review])

    Site.preloaded_category_custom_fields << Chat::HAS_CHAT_ENABLED

    Guardian.prepend Chat::GuardianExtensions
    UserNotifications.prepend Chat::UserNotificationsExtension
    UserOption.prepend Chat::UserOptionExtension
    Category.prepend Chat::CategoryExtension
    User.prepend Chat::UserExtension
    Jobs::UserEmail.prepend Chat::UserEmailExtension
    Bookmark.register_bookmarkable(ChatMessageBookmarkable)
  end

  if Oneboxer.respond_to?(:register_local_handler)
    Oneboxer.register_local_handler("chat/chat") do |url, route|
      if route[:message_id].present?
        message = ChatMessage.find_by(id: route[:message_id])
        next if !message

        chat_channel = message.chat_channel
        user = message.user
        next if !chat_channel || !user
      else
        chat_channel = ChatChannel.find_by(id: route[:channel_id])
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
        message = ChatMessage.find_by(id: route[:message_id])
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
        chat_channel = ChatChannel.find_by(id: route[:channel_id])
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
      ChatMessage.where(
        "message LIKE ? OR message LIKE ?",
        "%#{upload.sha1}%",
        "%#{upload.base62_sha1}%",
      ).exists? ||
        ChatDraft.where(
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

  add_to_serializer(:current_user, :can_chat) { true }

  add_to_serializer(:current_user, :include_can_chat?) do
    return @can_chat if defined?(@can_chat)

    @can_chat = SiteSetting.chat_enabled && scope.can_chat?
  end

  add_to_serializer(:current_user, :has_chat_enabled) { true }

  add_to_serializer(:current_user, :include_has_chat_enabled?) do
    return @has_chat_enabled if defined?(@has_chat_enabled)

    @has_chat_enabled = include_can_chat? && object.user_option.chat_enabled
  end

  add_to_serializer(:current_user, :chat_sound) { object.user_option.chat_sound }

  add_to_serializer(:current_user, :include_chat_sound?) do
    include_has_chat_enabled? && object.user_option.chat_sound
  end

  add_to_serializer(:current_user, :needs_channel_retention_reminder) { true }

  add_to_serializer(:current_user, :needs_dm_retention_reminder) { true }

  add_to_serializer(:current_user, :has_joinable_public_channels) do
    Chat::ChatChannelFetcher.secured_public_channel_search(
      self.scope,
      following: false,
      limit: 1,
      status: :open,
    ).exists?
  end

  add_to_serializer(:current_user, :chat_channels) do
    structured = Chat::ChatChannelFetcher.structured(self.scope)
    ChatChannelIndexSerializer.new(structured, scope: self.scope, root: false).as_json
  end

  add_to_serializer(:current_user, :include_needs_channel_retention_reminder?) do
    include_has_chat_enabled? && object.staff? &&
      !object.user_option.dismissed_channel_retention_reminder &&
      !SiteSetting.chat_channel_retention_days.zero?
  end

  add_to_serializer(:current_user, :include_needs_dm_retention_reminder?) do
    include_has_chat_enabled? && !object.user_option.dismissed_dm_retention_reminder &&
      !SiteSetting.chat_dm_retention_days.zero?
  end

  add_to_serializer(:current_user, :chat_drafts) do
    ChatDraft
      .where(user_id: object.id)
      .order(updated_at: :desc)
      .limit(20)
      .pluck(:chat_channel_id, :data)
      .map { |row| { channel_id: row[0], data: row[1] } }
  end

  add_to_serializer(:current_user, :include_chat_drafts?) { include_has_chat_enabled? }

  add_to_serializer(:user_option, :chat_enabled) { object.chat_enabled }

  add_to_serializer(:user_option, :chat_sound) { object.chat_sound }

  add_to_serializer(:user_option, :include_chat_sound?) { !object.chat_sound.blank? }

  add_to_serializer(:user_option, :only_chat_push_notifications) do
    object.only_chat_push_notifications
  end

  add_to_serializer(:user_option, :ignore_channel_wide_mention) do
    object.ignore_channel_wide_mention
  end

  add_to_serializer(:user_option, :chat_email_frequency) { object.chat_email_frequency }

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
  end

  on(:post_alerter_after_save_post) do |post, new_record, notified|
    next if !new_record
    Chat::PostNotificationHandler.new(post, notified).handle
  end

  register_presence_channel_prefix("chat") do |channel_name|
    next nil unless channel_name == "/chat/online"
    config = PresenceChannel::Config.new
    config.allowed_group_ids = Chat.allowed_group_ids
    config
  end

  register_presence_channel_prefix("chat-reply") do |channel_name|
    if chat_channel_id = channel_name[%r{/chat-reply/(\d+)}, 1]
      chat_channel = ChatChannel.find(chat_channel_id)

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
      ChatChannel
        .where(auto_join_users: true)
        .each do |channel|
          Chat::ChatChannelMembershipManager.new(channel).enforce_automatic_user_membership(user)
        end
    end
  end

  on(:user_confirmed_email) do |user|
    if user.active?
      ChatChannel
        .where(auto_join_users: true)
        .each do |channel|
          Chat::ChatChannelMembershipManager.new(channel).enforce_automatic_user_membership(user)
        end
    end
  end

  on(:user_added_to_group) do |user, group|
    channels_to_add =
      ChatChannel
        .distinct
        .where(auto_join_users: true, chatable_type: "Category")
        .joins(
          "INNER JOIN category_groups ON category_groups.category_id = chat_channels.chatable_id",
        )
        .where(category_groups: { group_id: group.id })

    channels_to_add.each do |channel|
      Chat::ChatChannelMembershipManager.new(channel).enforce_automatic_user_membership(user)
    end
  end

  on(:category_updated) do |category|
    # TODO(roman): remove early return after 2.9 release.
    # There's a bug on core where this event is triggered with an `#update` result (true/false)
    return if !category.is_a?(Category)
    category_channel = ChatChannel.find_by(auto_join_users: true, chatable: category)

    if category_channel
      Chat::ChatChannelMembershipManager.new(category_channel).enforce_automatic_channel_memberships
    end
  end

  Chat::Engine.routes.draw do
    namespace :api, defaults: { format: :json } do
      get "/chatables" => "chat_chatables#index"
      get "/channels" => "chat_channels#index"
      get "/channels/me" => "chat_current_user_channels#index"
      post "/channels" => "chat_channels#create"
      delete "/channels/:channel_id" => "chat_channels#destroy"
      put "/channels/:channel_id" => "chat_channels#update"
      get "/channels/:channel_id" => "chat_channels#show"
      put "/channels/:channel_id/status" => "chat_channels_status#update"
      post "/channels/:channel_id/messages/moves" => "chat_channels_messages_moves#create"
      post "/channels/:channel_id/archives" => "chat_channels_archives#create"
      get "/channels/:channel_id/memberships" => "chat_channels_memberships#index"
      delete "/channels/:channel_id/memberships/me" =>
               "chat_channels_current_user_membership#destroy"
      post "/channels/:channel_id/memberships/me" => "chat_channels_current_user_membership#create"
      put "/channels/:channel_id/notifications-settings/me" =>
            "chat_channels_current_user_notifications_settings#update"

      # Category chatables controller hints. Only used by staff members, we don't want to leak category permissions.
      get "/category-chatables/:id/permissions" => "category_chatables#permissions",
          :format => :json,
          :constraints => StaffConstraint.new

      # Hints for JIT warnings.
      get "/mentions/groups" => "hints#check_group_mentions", :format => :json

      get "/channels/:channel_id/threads/:thread_id" => "chat_channel_threads#show"
    end

    # direct_messages_controller routes
    get "/direct_messages" => "direct_messages#index"
    post "/direct_messages/create" => "direct_messages#create"

    # incoming_webhooks_controller routes
    post "/hooks/:key" => "incoming_chat_webhooks#create_message"

    # incoming_webhooks_controller routes
    post "/hooks/:key/slack" => "incoming_chat_webhooks#create_message_slack_compatible"

    # chat_controller routes
    get "/" => "chat#respond"
    get "/browse" => "chat#respond"
    get "/browse/all" => "chat#respond"
    get "/browse/closed" => "chat#respond"
    get "/browse/open" => "chat#respond"
    get "/browse/archived" => "chat#respond"
    get "/draft-channel" => "chat#respond"
    post "/enable" => "chat#enable_chat"
    post "/disable" => "chat#disable_chat"
    post "/dismiss-retention-reminder" => "chat#dismiss_retention_reminder"
    get "/:chat_channel_id/messages" => "chat#messages"
    get "/message/:message_id" => "chat#message_link"
    put ":chat_channel_id/edit/:message_id" => "chat#edit_message"
    put ":chat_channel_id/react/:message_id" => "chat#react"
    delete "/:chat_channel_id/:message_id" => "chat#delete"
    put "/:chat_channel_id/:message_id/rebake" => "chat#rebake"
    post "/:chat_channel_id/:message_id/flag" => "chat#flag"
    post "/:chat_channel_id/quote" => "chat#quote_messages"
    put "/:chat_channel_id/restore/:message_id" => "chat#restore"
    get "/lookup/:message_id" => "chat#lookup_message"
    put "/:chat_channel_id/read/:message_id" => "chat#update_user_last_read"
    put "/user_chat_enabled/:user_id" => "chat#set_user_chat_status"
    put "/:chat_channel_id/invite" => "chat#invite_users"
    post "/drafts" => "chat#set_draft"
    post "/:chat_channel_id" => "chat#create_message"
    put "/flag" => "chat#flag"
    get "/emojis" => "emojis#index"

    base_c_route = "/c/:channel_title/:channel_id"
    get base_c_route => "chat#respond", :as => "channel"
    get "#{base_c_route}/:message_id" => "chat#respond"

    %w[info info/about info/members info/settings].each do |route|
      get "#{base_c_route}/#{route}" => "chat#respond"
    end

    # /channel -> /c redirects
    get "/channel/:channel_id", to: redirect("/chat/c/-/%{channel_id}")

    get "#{base_c_route}/t/:thread_id" => "chat#respond"

    base_channel_route = "/channel/:channel_id/:channel_title"
    redirect_base = "/chat/c/%{channel_title}/%{channel_id}"

    get base_channel_route, to: redirect(redirect_base)

    %w[info info/about info/members info/settings].each do |route|
      get "#{base_channel_route}/#{route}", to: redirect("#{redirect_base}/#{route}")
    end
  end

  Discourse::Application.routes.append do
    mount ::Chat::Engine, at: "/chat"
    get "/admin/plugins/chat" => "chat/admin_incoming_chat_webhooks#index",
        :constraints => StaffConstraint.new
    post "/admin/plugins/chat/hooks" => "chat/admin_incoming_chat_webhooks#create",
         :constraints => StaffConstraint.new
    put "/admin/plugins/chat/hooks/:incoming_chat_webhook_id" =>
          "chat/admin_incoming_chat_webhooks#update",
        :constraints => StaffConstraint.new
    delete "/admin/plugins/chat/hooks/:incoming_chat_webhook_id" =>
             "chat/admin_incoming_chat_webhooks#destroy",
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
        channel = ChatChannel.find_by(id: fields.dig("chat_channel_id", "value"))

        placeholders = { channel_name: channel.title(sender) }.merge(context["placeholders"] || {})

        creator =
          Chat::ChatMessageCreator.create(
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

  # TODO(roman): Remove `respond_to?` after 2.9 release
  if respond_to?(:register_email_unsubscriber)
    load File.expand_path("../lib/email_controller_helper/chat_summary_unsubscriber.rb", __FILE__)
    register_email_unsubscriber("chat_summary", EmailControllerHelper::ChatSummaryUnsubscriber)
  end

  register_about_stat_group("chat_messages", show_in_ui: true) { Chat::Statistics.about_messages }

  register_about_stat_group("chat_channels") { Chat::Statistics.about_channels }

  register_about_stat_group("chat_users") { Chat::Statistics.about_users }

  # Make sure to update spec/system/hashtag_autocomplete_spec.rb when changing this.
  register_hashtag_data_source(Chat::ChatChannelHashtagDataSource)
  register_hashtag_type_priority_for_context("channel", "chat-composer", 200)
  register_hashtag_type_priority_for_context("category", "chat-composer", 100)
  register_hashtag_type_priority_for_context("tag", "chat-composer", 50)
  register_hashtag_type_priority_for_context("channel", "topic-composer", 10)

  Site.markdown_additional_options["chat"] = {
    limited_pretty_text_features: ChatMessage::MARKDOWN_FEATURES,
    limited_pretty_text_markdown_rules: ChatMessage::MARKDOWN_IT_RULES,
    hashtag_configurations: HashtagAutocompleteService.contexts_with_ordered_types,
  }

  register_user_destroyer_on_content_deletion_callback(
    Proc.new { |user| Jobs.enqueue(:delete_user_messages, user_id: user.id) },
  )
end

if Rails.env == "test"
  Dir[Rails.root.join("plugins/chat/spec/support/**/*.rb")].each { |f| require f }
end
