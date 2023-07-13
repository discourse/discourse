# frozen_string_literal: true

class PostValidator < ActiveModel::Validator
  def validate(record)
    presence(record)

    return if record.acting_user.try(:staged?)
    if record.acting_user.try(:admin?) && Discourse.static_doc_topic_ids.include?(record.topic_id)
      return
    end

    post_body_validator(record)
    max_posts_validator(record)
    max_mention_validator(record)
    max_embedded_media_validator(record)
    max_attachments_validator(record)
    can_post_links_validator(record)
    unique_post_validator(record)
    force_edit_last_validator(record)
  end

  def presence(post)
    unless options[:skip_topic]
      post.errors.add(:topic_id, :blank, **options) if post.topic_id.blank?
    end

    post.errors.add(:user_id, :blank, **options) if post.new_record? && post.user_id.nil?
  end

  def post_body_validator(post)
    return if options[:skip_post_body] || post.topic&.pm_with_non_human_user?
    stripped_length(post)
    raw_quality(post)
    WatchedWordsValidator.new(attributes: [:raw]).validate(post) if !post.acting_user&.staged
  end

  def stripped_length(post)
    range =
      if private_message?(post)
        # private message
        SiteSetting.private_message_post_length
      elsif post.is_first_post? || (post.topic.present? && post.topic.posts_count == 0)
        # creating/editing first post
        if post.topic&.featured_link&.present?
          (0..SiteSetting.max_post_length)
        else
          SiteSetting.first_post_length
        end
      else
        # regular post
        SiteSetting.post_length
      end

    StrippedLengthValidator.validate(post, :raw, post.raw, range)
  end

  def raw_quality(post)
    sentinel = TextSentinel.body_sentinel(post.raw, private_message: private_message?(post))
    post.errors.add(:raw, I18n.t(:is_invalid)) unless sentinel.valid?
  end

  # Ensure maximum amount of mentions in a post
  def max_mention_validator(post)
    return if post.acting_user.try(:staff?)

    if acting_user_is_trusted?(post) || private_message?(post)
      add_error_if_count_exceeded(
        post,
        :no_mentions_allowed,
        :too_many_mentions,
        post.raw_mentions.size,
        SiteSetting.max_mentions_per_post,
      )
    else
      add_error_if_count_exceeded(
        post,
        :no_mentions_allowed_newuser,
        :too_many_mentions_newuser,
        post.raw_mentions.size,
        SiteSetting.newuser_max_mentions_per_post,
      )
    end
  end

  def max_posts_validator(post)
    if post.new_record? && post.acting_user.present? &&
         post.acting_user.posted_too_much_in_topic?(post.topic_id)
      post.errors.add(
        :base,
        I18n.t(:too_many_replies, count: SiteSetting.newuser_max_replies_per_topic),
      )
    end
  end

  # Ensure new users can not put too many media embeds (images, video, audio) in a post
  def max_embedded_media_validator(post)
    return if post.acting_user.blank? || post.acting_user&.staff?

    if post.acting_user.trust_level < TrustLevel[SiteSetting.min_trust_to_post_embedded_media]
      add_error_if_count_exceeded(
        post,
        :no_embedded_media_allowed_trust,
        :no_embedded_media_allowed_trust,
        post.embedded_media_count,
        0,
      )
    elsif post.acting_user.trust_level == TrustLevel[0]
      add_error_if_count_exceeded(
        post,
        :no_embedded_media_allowed,
        :too_many_embedded_media,
        post.embedded_media_count,
        SiteSetting.newuser_max_embedded_media,
      )
    end
  end

  # Ensure new users can not put too many attachments in a post
  def max_attachments_validator(post)
    return if acting_user_is_trusted?(post) || private_message?(post)
    add_error_if_count_exceeded(
      post,
      :no_attachments_allowed,
      :too_many_attachments,
      post.attachment_count,
      SiteSetting.newuser_max_attachments,
    )
  end

  def can_post_links_validator(post)
    if (post.link_count == 0 && !post.has_oneboxes?) || private_message?(post)
      return newuser_links_validator(post)
    end

    guardian = Guardian.new(post.acting_user)
    if post.linked_hosts.keys.all? { |h| guardian.can_post_link?(host: h) }
      return newuser_links_validator(post)
    end

    post.errors.add(:base, I18n.t(:links_require_trust))
  end

  # Ensure new users can not put too many links in a post
  def newuser_links_validator(post)
    return if acting_user_is_trusted?(post) || private_message?(post)
    add_error_if_count_exceeded(
      post,
      :no_links_allowed,
      :too_many_links,
      post.link_count,
      SiteSetting.newuser_max_links,
    )
  end

  # Stop us from posting the same thing too quickly
  def unique_post_validator(post)
    return if SiteSetting.unique_posts_mins == 0
    return if post.skip_unique_check
    return if post.acting_user.try(:staff?)

    # If the post is empty, default to the validates_presence_of
    return if post.raw.blank?

    post.errors.add(:raw, I18n.t(:just_posted_that)) if post.matches_recent_post?
  end

  def force_edit_last_validator(post)
    if SiteSetting.max_consecutive_replies == 0 || post.id || post.acting_user&.staff? ||
         private_message?(post)
      return
    end

    topic = post.topic
    return if topic&.ordered_posts&.first&.user == post.user

    guardian = Guardian.new(post.acting_user)
    return if guardian.is_category_group_moderator?(post.topic&.category)

    last_posts_count =
      DB.query_single(
        <<~SQL,
      SELECT COUNT(*)
      FROM (
        SELECT user_id
          FROM posts
         WHERE deleted_at IS NULL
           AND NOT hidden
           AND topic_id = :topic_id
         ORDER BY post_number DESC
         LIMIT :max_replies
      ) c
      WHERE c.user_id = :user_id
    SQL
        topic_id: post.topic_id,
        user_id: post.acting_user.id,
        max_replies: SiteSetting.max_consecutive_replies,
      ).first
    return if last_posts_count < SiteSetting.max_consecutive_replies

    if guardian.can_edit?(topic.ordered_posts.last)
      post.errors.add(
        :base,
        I18n.t(:max_consecutive_replies, count: SiteSetting.max_consecutive_replies),
      )
    end
  end

  private

  def acting_user_is_trusted?(post, level = 1)
    post.acting_user.present? && post.acting_user.has_trust_level?(TrustLevel[level])
  end

  def private_message?(post)
    post.topic.try(:private_message?)
  end

  def add_error_if_count_exceeded(
    post,
    not_allowed_translation_key,
    limit_translation_key,
    current_count,
    max_count
  )
    if current_count > max_count
      if max_count == 0
        post.errors.add(:base, I18n.t(not_allowed_translation_key))
      else
        post.errors.add(:base, I18n.t(limit_translation_key, count: max_count))
      end
    end
  end
end
