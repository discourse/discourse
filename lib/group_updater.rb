# frozen_string_literal: true

class GroupUpdater
  # Raised when a notification-default change would alter existing members and
  # the caller has not said whether to apply it to them.
  class ExistingUsersConfirmationRequired < StandardError
    attr_reader :user_count

    def initialize(user_count)
      @user_count = user_count
      super(I18n.t("groups.errors.update_existing_users_required", count: user_count))
    end
  end

  NOTIFICATION_DEFAULT_LEVELS = %i[muted regular tracking watching watching_first_post].freeze
  BLANK_SELECTION = ["-1", -1].freeze

  def self.permitted_params(guardian, group:)
    new(guardian, group, {}).permitted_params
  end

  def self.permitted_names(guardian, group:)
    permitted_params(guardian, group:).flat_map do |attribute|
      attribute.is_a?(Hash) ? attribute.keys.map(&:to_s) : attribute.to_s
    end
  end

  def self.update(guardian, group, attributes, update_existing_users: nil)
    new(guardian, group, attributes, update_existing_users:).update
  end

  def initialize(guardian, group, attributes, update_existing_users: nil)
    @guardian = guardian
    @group = group
    @attributes = attributes.to_h.with_indifferent_access
    @update_existing_users = update_existing_users
  end

  def permitted_params
    attributes = %i[
      bio_raw
      default_notification_level
      messageable_level
      mentionable_level
      flair_bg_color
      flair_color
      flair_icon
      flair_upload_id
    ]

    if !group.automatic
      attributes.push(
        :allow_membership_requests,
        :full_name,
        :public_exit,
        :public_admission,
        :membership_request_template,
      )
    end

    attributes.push(:visibility_level, :members_visibility_level) if guardian.is_staff?

    if !group.automatic && guardian.is_staff?
      attributes.push(
        :incoming_email,
        :title,
        :primary_group,
        :name,
        :grant_trust_level,
        :publish_read_state,
      )

      custom_fields = DiscoursePluginRegistry.editable_group_custom_fields
      attributes << { custom_fields: custom_fields } if custom_fields.present?
    end

    if !group.automatic && guardian.is_admin?
      attributes.push(
        :smtp_server,
        :smtp_port,
        :smtp_ssl_mode,
        :smtp_enabled,
        :smtp_updated_by,
        :smtp_updated_at,
        :email_username,
        :email_password,
        :email_from_alias,
        :allow_unknown_sender_topic_replies,
      )
    end

    attributes << :automatic_membership_email_domains if !group.automatic && can_admin_group?

    if !group.automatic || guardian.is_admin?
      NOTIFICATION_DEFAULT_LEVELS.each do |level|
        attributes << { "#{level}_category_ids" => [] }
        attributes << { "#{level}_tags" => [] }
      end
    end

    attributes << { associated_group_ids: [] } if guardian.can_associate_groups?
    attributes.concat(DiscoursePluginRegistry.group_params)
    attributes
  end

  def update
    guardian.ensure_can_edit!(group) if !can_admin_group?

    @attributes = ActionController::Parameters.new(attributes).permit(*permitted_params).to_h
    group_attributes = attributes_without_disabled_email_settings
    notification_level, categories, tags = nil

    if !group.automatic || guardian.is_admin?
      changes = notification_default_changes(group_attributes)
      return false if !changes
      notification_level, categories, tags = changes

      if update_existing_users.nil?
        user_count = apply_to_existing_users(notification_level, categories, tags, mutate: false)
        raise ExistingUsersConfirmationRequired, user_count if user_count > 0
      end
    end

    return false if !group.update(group_attributes)

    GroupActionLogger.new(guardian.user, group).log_change_group_settings
    group.record_email_setting_changes!(guardian.user)
    if update_existing_users
      apply_to_existing_users(notification_level, categories, tags, mutate: true)
    end

    true
  end

  private

  attr_reader :guardian, :group, :attributes, :update_existing_users

  def can_admin_group?
    return @can_admin_group if defined?(@can_admin_group)
    @can_admin_group = guardian.can_admin_group?(group)
  end

  def attributes_without_disabled_email_settings
    return attributes if !group.smtp_enabled
    return attributes if !attributes.key?(:smtp_enabled)
    return attributes if ActiveModel::Type::Boolean.new.cast(attributes[:smtp_enabled]) != false

    attributes.merge(
      smtp_server: nil,
      smtp_ssl_mode: Group.smtp_ssl_modes[:none],
      smtp_port: nil,
      email_username: nil,
      email_password: nil,
    )
  end

  def notification_default_changes(group_attributes)
    category_notifications =
      group.group_category_notification_defaults.pluck(:category_id, :notification_level).to_h
    tag_notifications =
      group.group_tag_notification_defaults.pluck(:tag_id, :notification_level).to_h
    categories = {}
    tags = {}
    selected_categories = Set.new
    selected_tags = Set.new

    NotificationLevels.all.each do |key, value|
      category_ids =
        Category.where(id: Array(group_attributes[:"#{key}_category_ids"]) - BLANK_SELECTION).pluck(
          :id,
        )
      tag_names = Array(group_attributes[:"#{key}_tags"]) - BLANK_SELECTION
      tag_ids = GroupTagNotificationDefault.resolve_tag_ids(tag_names)

      if selected_categories.intersect?(category_ids) || selected_tags.intersect?(tag_ids)
        group.errors.add(:base, I18n.t("groups.errors.conflicting_notification_defaults"))
        return false
      end
      selected_categories.merge(category_ids)
      selected_tags.merge(tag_ids)

      category_ids.each do |category_id|
        metadata = change_metadata(category_notifications, category_id, value)
        categories[category_id] = metadata if metadata
      end

      tag_ids.each do |tag_id|
        metadata = change_metadata(tag_notifications, tag_id, value)
        tags[tag_id] = metadata if metadata
      end
    end

    (category_notifications.keys - categories.keys).each do |category_id|
      level = NotificationLevels.all.key(category_notifications[category_id])
      next if !group_attributes.key?(:"#{level}_category_ids")

      categories[category_id] = { action: :delete, old_value: category_notifications[category_id] }
    end

    (tag_notifications.keys - tags.keys).each do |tag_id|
      level = NotificationLevels.all.key(tag_notifications[tag_id])
      next if !group_attributes.key?(:"#{level}_tags")

      tags[tag_id] = { action: :delete, old_value: tag_notifications[tag_id] }
    end

    notification_level = nil
    default_notification_level = group_attributes[:default_notification_level]&.to_i

    if default_notification_level.present? &&
         group.default_notification_level != default_notification_level
      notification_level = {
        old_value: group.default_notification_level,
        new_value: default_notification_level,
      }
    end

    [notification_level, categories, tags]
  end

  # Returns nil when the existing default already matches, which also drops the
  # target from the "no longer defaulted" set computed by the caller.
  def change_metadata(existing, id, new_value)
    old_value = existing[id]
    return { old_value:, new_value:, action: :create } if old_value.blank?

    if old_value == new_value
      existing.delete(id)
      return nil
    end

    { old_value:, new_value:, action: :update }
  end

  def apply_to_existing_users(notification_level, categories, tags, mutate:)
    return 0 if notification_level.blank? && categories.blank? && tags.blank?

    group_users = group.group_users
    user_ids = []

    if notification_level.present?
      users = group_users.where(notification_level: notification_level[:old_value])

      if mutate
        users.update_all(notification_level: notification_level[:new_value])
      else
        user_ids += users.pluck(:user_id)
      end
    end

    categories.to_a.each do |category_id, data|
      next if data[:action] != :update && data[:action] != :delete

      category_users =
        CategoryUser.where(
          category_id:,
          notification_level: data[:old_value],
          user_id: group_users.select(:user_id),
        )

      if mutate
        category_users.delete_all
      else
        user_ids += category_users.pluck(:user_id)
      end

      categories.delete(category_id) if data[:action] == :delete && mutate
    end

    tags.to_a.each do |tag_id, data|
      next if data[:action] != :update && data[:action] != :delete

      tag_users =
        TagUser.where(
          tag_id:,
          notification_level: data[:old_value],
          user_id: group_users.select(:user_id),
        )

      if mutate
        tag_users.delete_all
      else
        user_ids += tag_users.pluck(:user_id)
      end

      tags.delete(tag_id) if data[:action] == :delete && mutate
    end

    if categories.present? || tags.present?
      user_ids += backfill_notification_defaults(group_users, categories, tags, mutate:)
    end

    user_ids.uniq.count
  end

  def backfill_notification_defaults(group_users, categories, tags, mutate:)
    user_ids = []

    group_users
      .select(:id, :user_id)
      .find_in_batches do |batch|
        batch_user_ids = batch.pluck(:user_id)

        categories.each do |category_id, data|
          skip_user_ids =
            CategoryUser
              .where(category_id:, user_id: batch_user_ids)
              .where.not(notification_level: nil)
              .pluck(:user_id)
          rows =
            (batch_user_ids - skip_user_ids).map do |user_id|
              { category_id:, user_id:, notification_level: data[:new_value] }
            end
          next if rows.blank?

          mutate ? CategoryUser.insert_all!(rows) : user_ids += rows.pluck(:user_id)
        end

        tags.each do |tag_id, data|
          skip_user_ids =
            TagUser
              .where(tag_id:, user_id: batch_user_ids)
              .where.not(notification_level: nil)
              .pluck(:user_id)
          rows =
            (batch_user_ids - skip_user_ids).map do |user_id|
              {
                tag_id:,
                user_id:,
                notification_level: data[:new_value],
                created_at: Time.zone.now,
                updated_at: Time.zone.now,
              }
            end
          next if rows.blank?

          mutate ? TagUser.insert_all!(rows) : user_ids += rows.pluck(:user_id)
        end
      end

    user_ids
  end
end
