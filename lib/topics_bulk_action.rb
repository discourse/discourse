# frozen_string_literal: true

class TopicsBulkAction

  def initialize(user, topic_ids, operation, options = {})
    @user = user
    @topic_ids = topic_ids
    @operation = operation
    @changed_ids = []
    @options = options
  end

  def self.operations
    @operations ||= %w(change_category close archive change_notification_level
                       reset_read dismiss_posts delete unlist archive_messages
                       move_messages_to_inbox change_tags append_tags relist)
  end

  def self.register_operation(name, &block)
    operations << name
    define_method(name, &block)
  end

  def perform!
    raise Discourse::InvalidParameters.new(:operation) unless TopicsBulkAction.operations.include?(@operation[:type])
    # careful these are private methods, we need send
    send(@operation[:type])
    @changed_ids
  end

  private

  def find_group
    return unless @options[:group]

    group = Group.where('name ilike ?', @options[:group]).first
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
          GroupArchivedMessage.move_to_inbox!(group.id, t)
        else
          UserArchivedMessage.move_to_inbox!(@user.id, t)
        end
      end
    end
  end

  def archive_messages
    group = find_group
    topics.each do |t|
      if guardian.can_see?(t) && t.private_message?
        if group
          GroupArchivedMessage.archive!(group.id, t)
        else
          UserArchivedMessage.archive!(@user.id, t)
        end
      end
    end
  end

  def dismiss_posts
    highest_number_source_column = @user.staff? ? 'highest_staff_post_number' : 'highest_post_number'
    sql = <<~SQL
      UPDATE topic_users tu
      SET highest_seen_post_number = t.#{highest_number_source_column} , last_read_post_number = t.#{highest_number_source_column}
      FROM topics t
      WHERE t.id = tu.topic_id AND tu.user_id = :user_id AND t.id IN (:topic_ids)
    SQL

    DB.exec(sql, user_id: @user.id, topic_ids: @topic_ids)
    @changed_ids.concat @topic_ids
  end

  def reset_read
    PostTiming.destroy_for(@user.id, @topic_ids)
  end

  def change_category
    topics.each do |t|
      if guardian.can_edit?(t)
        @changed_ids << t.id if t.change_category_to_id(@operation[:category_id])
      end
    end
  end

  def change_notification_level
    topics.each do |t|
      if guardian.can_see?(t)
        TopicUser.change(@user, t.id, notification_level: @operation[:notification_level_id].to_i)
        @changed_ids << t.id
      end
    end
  end

  def close
    topics.each do |t|
      if guardian.can_moderate?(t)
        t.update_status('closed', true, @user)
        @changed_ids << t.id
      end
    end
  end

  def unlist
    topics.each do |t|
      if guardian.can_moderate?(t)
        t.update_status('visible', false, @user)
        @changed_ids << t.id
      end
    end
  end

  def relist
    topics.each do |t|
      if guardian.can_moderate?(t)
        t.update_status('visible', true, @user)
        @changed_ids << t.id
      end
    end
  end

  def archive
    topics.each do |t|
      if guardian.can_moderate?(t)
        t.update_status('archived', true, @user)
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
    tags = @operation[:tags]
    tags = DiscourseTagging.tags_for_saving(tags, guardian) if tags.present?

    topics.each do |t|
      if guardian.can_edit?(t)
        if tags.present?
          DiscourseTagging.tag_topic_by_names(t, guardian, tags)
        else
          t.tags = []
        end
        @changed_ids << t.id
      end
    end
  end

  def append_tags
    tags = @operation[:tags]
    tags = DiscourseTagging.tags_for_saving(tags, guardian) if tags.present?

    topics.each do |t|
      if guardian.can_edit?(t)
        if tags.present?
          DiscourseTagging.tag_topic_by_names(t, guardian, tags, append: true)
        end
        @changed_ids << t.id
      end
    end
  end

  def guardian
    @guardian ||= Guardian.new(@user)
  end

  def topics
    @topics ||= Topic.where(id: @topic_ids)
  end

end
