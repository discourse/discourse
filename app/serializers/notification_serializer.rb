# frozen_string_literal: true

class NotificationSerializer < ApplicationSerializer
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
             :acting_user_avatar_template

  def slug
    Slug.for(object.topic.title) if object.topic.present?
  end

  def is_warning
    object.topic.present? && object.topic.subtype == TopicSubtype.moderator_warning
  end

  def include_fancy_title?
    object.topic&.fancy_title
  end

  def fancy_title
    object.topic.fancy_title
  end

  def include_is_warning?
    is_warning
  end

  def data
    object.data_hash
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
    SiteSetting.show_user_menu_avatars
  end
end
