class TopicsBulkAction

  def initialize(user, topic_ids, operation)
    @user = user
    @topic_ids = topic_ids
    @operation = operation
    @changed_ids = []
  end

  def self.operations
    %w(change_category close change_notification_level reset_read)
  end

  def perform!
    raise Discourse::InvalidParameters.new(:operation) unless TopicsBulkAction.operations.include?(@operation[:type])
    send(@operation[:type])
    @changed_ids
  end

  private

    def reset_read
      PostTiming.destroy_for(@user.id, @topic_ids)
    end

    def change_category
      topics.each do |t|
        if guardian.can_edit?(t)
          @changed_ids << t.id if t.change_category(@operation[:category_name])
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

    def guardian
      @guardian ||= Guardian.new(@user)
    end

    def topics
      @topics ||= Topic.where(id: @topic_ids)
    end

end

