# frozen_string_literal: true

class GroupShowSerializer < BasicGroupSerializer
  attributes :is_group_user, :is_group_owner, :is_group_owner_display, :mentionable, :messageable, :flair_icon, :flair_type

  def self.admin_attributes(*attrs)
    attributes(*attrs)
    attrs.each do |attr|
      define_method "include_#{attr}?" do
        scope.is_admin?
      end
    end
  end

  has_one :smtp_updated_by, embed: :object, serializer: BasicUserSerializer
  has_one :imap_updated_by, embed: :object, serializer: BasicUserSerializer

  admin_attributes :automatic_membership_email_domains,
                   :smtp_server,
                   :smtp_port,
                   :smtp_ssl,
                   :smtp_enabled,
                   :smtp_updated_at,
                   :smtp_updated_by,
                   :imap_server,
                   :imap_port,
                   :imap_ssl,
                   :imap_mailbox_name,
                   :imap_mailboxes,
                   :imap_enabled,
                   :imap_updated_at,
                   :imap_updated_by,
                   :email_username,
                   :email_password,
                   :email_from_alias,
                   :imap_last_error,
                   :imap_old_emails,
                   :imap_new_emails,
                   :message_count,
                   :allow_unknown_sender_topic_replies,
                   :associated_group_ids

  def self.admin_or_owner_attributes(*attrs)
    attributes(*attrs)
    attrs.each do |attr|
      define_method "include_#{attr}?" do
        scope.is_admin? || (include_is_group_owner? && is_group_owner)
      end
    end
  end

  admin_or_owner_attributes :watching_category_ids,
                            :tracking_category_ids,
                            :watching_first_post_category_ids,
                            :regular_category_ids,
                            :muted_category_ids,
                            :watching_tags,
                            :watching_first_post_tags,
                            :tracking_tags,
                            :regular_tags,
                            :muted_tags

  def include_is_group_user?
    authenticated?
  end

  def is_group_user
    !!fetch_group_user
  end

  def include_is_group_owner?
    authenticated? && fetch_group_user&.owner
  end

  def is_group_owner
    true
  end

  def include_is_group_owner_display?
    authenticated?
  end

  def is_group_owner_display
    !!fetch_group_user&.owner
  end

  def include_mentionable?
    authenticated?
  end

  def include_messageable?
    authenticated?
  end

  def mentionable
    Group.mentionable(scope.user).exists?(id: object.id)
  end

  def messageable
    scope.can_send_private_message?(object)
  end

  def include_flair_icon?
    flair_icon.present? && (is_group_owner || scope.is_admin?)
  end

  def include_flair_type?
    flair_type.present? && (is_group_owner || scope.is_admin?)
  end

  [:watching, :regular, :tracking, :watching_first_post, :muted].each do |level|
    define_method("#{level}_category_ids") do
      group_category_notifications[NotificationLevels.all[level]] || []
    end

    define_method("include_#{level}_tags?") do
      SiteSetting.tagging_enabled? &&
        scope.is_admin? || (include_is_group_owner? && is_group_owner)
    end

    define_method("#{level}_tags") do
      group_tag_notifications[NotificationLevels.all[level]] || []
    end
  end

  def associated_group_ids
    object.associated_groups.map(&:id)
  end

  def include_associated_group_ids?
    scope.can_associate_groups?
  end

  private

  def authenticated?
    scope.authenticated?
  end

  def fetch_group_user
    return @group_user if defined?(@group_user)
    @group_user = object.group_users.find_by(user: scope.user)
  end

  def group_category_notifications
    @group_category_notification_defaults ||=
      GroupCategoryNotificationDefault.where(group_id: object.id)
        .pluck(:notification_level, :category_id)
        .inject({}) do |h, arr|
          h[arr[0]] ||= []
          h[arr[0]] << arr[1]
          h
        end
  end

  def group_tag_notifications
    @group_tag_notification_defaults ||=
      GroupTagNotificationDefault.where(group_id: object.id)
        .joins(:tag)
        .pluck(:notification_level, :name)
        .inject({}) do |h, arr|
          h[arr[0]] ||= []
          h[arr[0]] << arr[1]
          h
        end
  end
end
