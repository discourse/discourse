# frozen_string_literal: true

class NotificationSerializer < ApplicationSerializer
  include LocalizedFancyTopicTitleMixin

  attributes :id,
             :user_id,
             :external_id,
             :notification_type,
             :read,
             :high_priority,
             :created_at,
             :post_number,
             :topic_id,
             :fancy_title,
             :slug,
             :data,
             :is_warning,
             :acting_user_avatar_template,
             :acting_user_name

  def slug
    return unless topic = object.topic

    topic[:slug].presence || Slug.for(topic.title)
  end

  def is_warning
    object.topic.present? && object.topic.subtype == TopicSubtype.moderator_warning
  end

  def include_is_warning?
    is_warning
  end

  def data
    Notification.populate_acting_user([object]) if object.users_by_id.nil?
    raw = object.data_hash
    enable_names = SiteSetting.enable_names?
    result = raw.except(*Notification::SERIALIZER_EXCLUDED_DATA_KEYS)

    Notification::USER_REFERENCE_FIELDS.each do |id_key, username_key, name_key|
      if (uid = raw[id_key]).present?
        if (user = object.users_by_id[uid.to_i])
          result[username_key] = user.username
          result[name_key] = user.name if enable_names && name_key && user.name.present?
        end
      elsif (legacy_username = raw[username_key]).present?
        user = object.users_by_username&.dig(legacy_username.to_s.downcase)
        result[name_key] = user.name if enable_names && name_key && user&.name.present?
      end
    end

    if raw[:display_label].present? && !result.key?(:display_username)
      result[:display_username] = raw[:display_label]
    end

    result
  end

  def external_id
    object.user&.single_sign_on_record&.external_id
  end

  def include_external_id?
    SiteSetting.enable_discourse_connect
  end

  def acting_user_avatar_template
    object.acting_user.avatar_template_url
  end

  def include_acting_user_avatar_template?
    object.acting_user.present?
  end

  def acting_user_name
    object.acting_user.name
  end

  def include_acting_user_name?
    object.acting_user.present? && SiteSetting.enable_names?
  end
end
