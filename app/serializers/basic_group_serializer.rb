# frozen_string_literal: true

class BasicGroupSerializer < ApplicationSerializer
  attributes :id,
             :automatic,
             :name,
             :display_name,
             :user_count,
             :mentionable_level,
             :messageable_level,
             :visibility_level,
             :automatic_membership_email_domains,
             :primary_group,
             :title,
             :grant_trust_level,
             :incoming_email,
             :has_messages,
             :flair_url,
             :flair_bg_color,
             :flair_color,
             :bio_raw,
             :bio_cooked,
             :bio_excerpt,
             :public_admission,
             :public_exit,
             :allow_membership_requests,
             :full_name,
             :default_notification_level,
             :membership_request_template,
             :is_group_user,
             :is_group_owner,
             :members_visibility_level,
             :can_see_members,
             :publish_read_state

  def self.admin_attributes(*attrs)
    attributes(*attrs)
    attrs.each do |attr|
      define_method "include_#{attr}?" do
        scope.is_admin?
      end
    end
  end

  admin_attributes :automatic_membership_email_domains,
                   :smtp_server,
                   :smtp_port,
                   :smtp_ssl,
                   :imap_server,
                   :imap_port,
                   :imap_ssl,
                   :imap_mailbox_name,
                   :imap_mailboxes,
                   :email_username,
                   :email_password,
                   :imap_last_error,
                   :imap_old_emails,
                   :imap_new_emails

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
                            :muted_category_ids,
                            :watching_tags,
                            :watching_first_post_tags,
                            :tracking_tags,
                            :muted_tags

  def include_display_name?
    object.automatic
  end

  def display_name
    if auto_group_name = Group::AUTO_GROUP_IDS[object.id]
      I18n.t("groups.default_names.#{auto_group_name}")
    end
  end

  def bio_excerpt
    PrettyText.excerpt(object.bio_cooked, 110, keep_emoji_images: true) if object.bio_cooked.present?
  end

  def include_incoming_email?
    staff?
  end

  def include_has_messages?
    staff? || scope.can_see_group_messages?(object)
  end

  def include_bio_raw?
    staff? || (include_is_group_owner? && is_group_owner)
  end

  def include_is_group_user?
    user_group_ids.present?
  end

  def is_group_user
    user_group_ids.include?(object.id)
  end

  def include_is_group_owner?
    owner_group_ids.present?
  end

  def is_group_owner
    owner_group_ids.include?(object.id)
  end

  def can_see_members
    scope.can_see_group_members?(object)
  end

  [:watching, :tracking, :watching_first_post, :muted].each do |level|
    define_method("#{level}_category_ids") do
      GroupCategoryNotificationDefault.lookup(object, level).pluck(:category_id)
    end

    define_method("#{level}_tags") do
      GroupTagNotificationDefault.lookup(object, level).joins(:tag).pluck('tags.name')
    end
  end

  private

  def staff?
    @staff ||= scope.is_staff?
  end

  def user_group_ids
    @options[:user_group_ids]
  end

  def owner_group_ids
    @options[:owner_group_ids]
  end
end
