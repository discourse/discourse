# frozen_string_literal: true

class UserCardSerializer < BasicUserSerializer
  attr_accessor :topic_post_count

  def self.staff_attributes(*attrs)
    attributes(*attrs)
    attrs.each do |attr|
      define_method "include_#{attr}?" do
        scope.is_staff?
      end
    end
  end

  def self.private_attributes(*attrs)
    attributes(*attrs)
    attrs.each do |attr|
      define_method "include_#{attr}?" do
        can_edit
      end
    end
  end

  # attributes that are hidden for TL0 users when seen by anonymous
  def self.untrusted_attributes(*attrs)
    attributes(*attrs)
    attrs.each do |attr|
      method_name = "include_#{attr}?"
      define_method(method_name) do
        return false if scope.restrict_user_fields?(object)
        public_send(attr).present?
      end
    end
  end

  attributes :email,
             :last_posted_at,
             :last_seen_at,
             :created_at,
             :ignored,
             :muted,
             :can_ignore_user,
             :can_mute_user,
             :can_send_private_messages,
             :can_send_private_message_to_user,
             :trust_level,
             :moderator,
             :admin,
             :title,
             :suspend_reason,
             :suspended_till,
             :badge_count,
             :user_fields,
             :custom_fields,
             :topic_post_count,
             :time_read,
             :recent_time_read,
             :primary_group_id,
             :primary_group_name,
             :primary_group_flair_url,
             :primary_group_flair_bg_color,
             :primary_group_flair_color,
             :featured_topic

  untrusted_attributes :bio_excerpt,
                       :website,
                       :website_name,
                       :location,
                       :card_background_upload_url

  staff_attributes :staged

  has_many :featured_user_badges, embed: :ids, serializer: UserBadgeSerializer, root: :user_badges

  def include_email?
    (object.id && object.id == scope.user.try(:id)) ||
      (scope.is_staff? && object.staged?)
  end

  def bio_excerpt
    object.user_profile.bio_excerpt(350, keep_newlines: true, keep_emoji_images: true)
  end

  def location
    object.user_profile.location
  end

  def website
    object.user_profile.website
  end

  def website_name
    uri = begin
      URI(website.to_s)
    rescue URI::Error
    end

    return if uri.nil? || uri.host.nil?
    uri.host.sub(/^www\./, '') + uri.path
  end

  def include_website_name
    website.present?
  end

  def ignored
    scope_ignored_user_ids = scope.user&.ignored_user_ids || []
    scope_ignored_user_ids.include?(object.id)
  end

  def muted
    scope_muted_user_ids = scope.user&.muted_user_ids || []
    scope_muted_user_ids.include?(object.id)
  end

  def can_mute_user
    scope.can_mute_user?(object)
  end

  def can_ignore_user
    scope.can_ignore_user?(object)
  end

  # Needed because 'send_private_message_to_user' will always return false
  # when the current user is being serialized
  def can_send_private_messages
    scope.can_send_private_message?(Discourse.system_user)
  end

  def can_send_private_message_to_user
    scope.can_send_private_message?(object) && scope.current_user != object
  end

  def include_suspend_reason?
    scope.can_see_suspension_reason?(object) && object.suspended?
  end

  def include_suspended_till?
    object.suspended?
  end

  def user_fields
    allowed_keys = scope.allowed_user_field_ids(object).map(&:to_s)
    object.user_fields&.select { |k, v| allowed_keys.include?(k) }
  end

  def include_user_fields?
    user_fields.present?
  end

  def custom_fields
    fields = User.whitelisted_user_custom_fields(scope)

    if scope.can_edit?(object)
      fields += DiscoursePluginRegistry.serialized_current_user_fields.to_a
    end

    if fields.present?
      User.custom_fields_for_ids([object.id], fields)[object.id] || {}
    else
      {}
    end
  end

  def include_topic_post_count?
    topic_post_count.present?
  end

  def time_read
    object.user_stat&.time_read
  end

  def recent_time_read
    time = object.recent_time_read
  end

  def primary_group_name
    object.primary_group.try(:name)
  end

  def primary_group_flair_url
    object.try(:primary_group).try(:flair_url)
  end

  def primary_group_flair_bg_color
    object.try(:primary_group).try(:flair_bg_color)
  end

  def primary_group_flair_color
    object.try(:primary_group).try(:flair_color)
  end

  def featured_topic
    object.user_profile.featured_topic
  end

  def card_background_upload_url
    object.card_background_upload&.url
  end
end
