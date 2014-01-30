class TopicsBulkAction

  def initialize(user, topic_ids, operation)
    @user = user
    @topic_ids = topic_ids
    @operation = operation
  end

  def self.operations
    %w(change_category)
  end

  def perform!
    raise Discourse::InvalidParameters.new(:operation) unless TopicsBulkAction.operations.include?(@operation[:type])
    send(@operation[:type])
  end

  private

    def change_category
      changed_ids = []
      topics.each do |t|
        if guardian.can_edit?(t)
          changed_ids << t.id if t.change_category(@operation[:category_name])
        end
      end
      changed_ids
    end

    def guardian
      @guardian ||= Guardian.new(@user)
    end

    def topics
      @topics ||= Topic.where(id: @topic_ids)
    end

end

