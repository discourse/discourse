# frozen_string_literal: true

class TopicsBulkAction
  attr_reader :errors

  def initialize(user, topic_ids, operation, options = {})
    @user = user
    @topic_ids = topic_ids
    @operation = operation
    @changed_ids = []
    @errors = Hash.new(0)
    @options = options
  end

  def self.operations
    @operations ||= %w[
      change_category
      close
      archive
      change_notification_level
      destroy_post_timing
      dismiss_posts
      delete
      unlist
      archive_messages
      move_messages_to_inbox
      change_tags
      append_tags
      remove_tags
      relist
      dismiss_topics
      reset_bump_dates
    ]
  end

  def self.register_operation(name, &block)
    operations << name
    define_method(name, &block)
  end

  def perform!
    if TopicsBulkAction.operations.exclude?(@operation[:type])
      raise Discourse::InvalidParameters.new(:operation)
    end

    # careful these are private methods, we need send
    send(@operation[:type])

    if @errors.present?
      error_details = @errors.map { |msg, count| "- #{msg} (#{count} topics)" }.join("\n")
      Rails.logger.warn(
        "Bulk '#{@operation[:type]}' by @#{@user.username} (id=#{@user.id}) failed for #{@errors.values.sum} topics:\n#{error_details}",
      )
    end

    @changed_ids.sort
  end

  private

  def find_group
    return unless @options[:group]

    group = Group.where("name ilike ?", @options[:group]).first
    raise Discourse::InvalidParameters.new(:group) unless group
    unless group.group_users.where(user_id: @user.id).exists?
      raise Discourse::InvalidParameters.new(:group)
    end
    group
  end

  def move_messages_to_inbox
    group = find_group
    topics.each do |t|
      if guardian.can_see?(t) && t.private_message?
        if group
          GroupArchivedMessage.move_to_inbox!(group.id, t, acting_user_id: @user.id)
        else
          UserArchivedMessage.move_to_inbox!(@user.id, t)
        end
        @changed_ids << t.id
      end
    end
  end

  def archive_messages
    group = find_group
    topics.each do |t|
      if guardian.can_see?(t) && t.private_message?
        if group
          GroupArchivedMessage.archive!(group.id, t, acting_user_id: @user.id)
        else
          UserArchivedMessage.archive!(@user.id, t)
        end
        @changed_ids << t.id
      end
    end
  end

  def dismiss_posts
    highest_number_source_column =
      @user.whisperer? ? "highest_staff_post_number" : "highest_post_number"

    sql = <<~SQL
      UPDATE topic_users tu
      SET last_read_post_number = t.#{highest_number_source_column}
      FROM topics t
      WHERE t.id = tu.topic_id AND tu.user_id = :user_id AND t.id IN (:topic_ids)
    SQL

    DB.exec(sql, user_id: @user.id, topic_ids: @topic_ids)
    TopicTrackingState.publish_dismiss_new_posts(@user.id, topic_ids: @topic_ids.sort)

    @changed_ids.concat @topic_ids
  end

  def dismiss_topics
    ids =
      Topic
        .where(id: @topic_ids)
        .joins(
          "LEFT JOIN topic_users ON topic_users.topic_id = topics.id AND topic_users.user_id = #{@user.id}",
        )
        .where("topics.created_at >= ?", dismiss_topics_since_date)
        .where("topic_users.last_read_post_number IS NULL")
        .order("topics.created_at DESC")
        .limit(SiteSetting.max_new_topics)
        .filter { |t| guardian.can_see?(t) }
        .map(&:id)

    if ids.present?
      now = Time.zone.now
      rows = ids.map { |id| { topic_id: id, user_id: @user.id, created_at: now } }
      DismissedTopicUser.insert_all(rows)
      TopicTrackingState.publish_dismiss_new(@user.id, topic_ids: ids.sort)
    end

    @changed_ids = ids
  end

  def destroy_post_timing
    topics.each do |t|
      PostTiming.destroy_last_for(@user, topic: t)
      @changed_ids << t.id
    end
  end

  def change_category
    updatable_topics = topics.where.not(category_id: @operation[:category_id])

    opts = {
      bypass_bump: true,
      validate_post: false,
      bypass_rate_limiter: true,
      silent: @operation[:silent],
      skip_revision: !SiteSetting.create_revision_on_bulk_topic_moves,
    }

    updatable_topics.each do |t|
      if guardian.can_edit?(t)
        changes = { category_id: @operation[:category_id] }
        if t.first_post.revise(@user, changes, opts)
          @changed_ids << t.id
        else
          t.errors.full_messages.each { |msg| @errors[msg] += 1 }
        end
      end
    end
  end

  def change_notification_level
    notification_level_id = @operation[:notification_level_id]

    raise Discourse::InvalidParameters.new(:notification_level_id) if notification_level_id.blank?

    topics.each do |t|
      if guardian.can_see?(t)
        TopicUser.change(@user, t.id, notification_level: notification_level_id.to_i)
        @changed_ids << t.id
      end
    end
  end

  def close
    topics.each do |t|
      if guardian.can_moderate?(t)
        t.update_status(
          "closed",
          true,
          @user,
          { message: @operation[:message], silent_tracking: @operation[:silent] },
        )
        @changed_ids << t.id
      end
    end
  end

  def unlist
    topics.each do |t|
      if guardian.can_moderate?(t)
        t.update_status(
          "visible",
          false,
          @user,
          { visibility_reason_id: Topic.visibility_reasons[:bulk_action] },
        )
        @changed_ids << t.id
      end
    end
  end

  def relist
    topics.each do |t|
      if guardian.can_moderate?(t)
        t.update_status(
          "visible",
          true,
          @user,
          { visibility_reason_id: Topic.visibility_reasons[:bulk_action] },
        )
        @changed_ids << t.id
      end
    end
  end

  def reset_bump_dates
    if guardian.can_update_bumped_at?
      topics.each do |t|
        t.reset_bumped_at
        @changed_ids << t.id
      end
    end
  end

  def archive
    topics.each do |t|
      if guardian.can_moderate?(t)
        t.update_status("archived", true, @user)
        @changed_ids << t.id
      end
    end
  end

  def delete
    topics.each do |t|
      if guardian.can_delete?(t)
        post = t.ordered_posts.first
        PostDestroyer.new(@user, post).destroy if post
      end
    end
  end

  def change_tags
    tags = resolve_tag_names || []

    topics_with_tags.each do |t|
      next unless guardian.can_edit?(t)
      next unless t.first_post

      if t.first_post.revise(@user, { tags: tags }, bulk_tag_opts)
        @changed_ids << t.id
      else
        t.errors.full_messages.each { |msg| @errors[msg] += 1 }
      end
    end
  end

  def append_tags
    tags = resolve_tag_names || []

    return if tags.blank?

    topics_with_tags.each do |t|
      next unless guardian.can_edit?(t)
      next unless t.first_post

      merged = t.tags.map(&:name) | tags
      if t.first_post.revise(@user, { tags: merged }, bulk_tag_opts)
        @changed_ids << t.id
      else
        t.errors.full_messages.each { |msg| @errors[msg] += 1 }
      end
    end
  end

  def remove_tags
    topics_with_tags.each do |t|
      next unless guardian.can_edit?(t)
      next unless t.first_post

      if t.first_post.revise(@user, { tags: [] }, bulk_tag_opts)
        @changed_ids << t.id
      else
        t.errors.full_messages.each { |msg| @errors[msg] += 1 }
      end
    end
  end

  def resolve_tag_names
    if @operation[:tag_ids].present?
      Tag.where(id: @operation[:tag_ids]).pluck(:name)
    elsif @operation[:tags].present?
      Discourse.deprecate(
        "the tags param for bulk actions is deprecated, use tag_ids instead",
        since: "2026.01",
        drop_from: "2026.07",
      )
      @operation[:tags]
    end
  end

  def bulk_tag_opts
    {
      bypass_bump: true,
      validate_post: false,
      bypass_rate_limiter: true,
      skip_revision: true,
      silent: true,
    }
  end

  def guardian
    @guardian ||= Guardian.new(@user)
  end

  def topics
    @topics ||= Topic.where(id: @topic_ids)
  end

  def topics_with_tags
    @topics_with_tags ||= topics.includes(:first_post, :tags)
  end

  def dismiss_topics_since_date
    new_topic_duration_minutes =
      @user.user_option&.new_topic_duration_minutes ||
        SiteSetting.default_other_new_topic_duration_minutes
    setting_date =
      case new_topic_duration_minutes
      when User::NewTopicDuration::LAST_VISIT
        @user.previous_visit_at || @user.created_at
      when User::NewTopicDuration::ALWAYS
        @user.created_at
      else
        new_topic_duration_minutes.minutes.ago
      end
    [setting_date, @user.created_at, Time.at(SiteSetting.min_new_topics_time).to_datetime].max
  end
end
