module Jobs
  class CloseTopic < Jobs::Base

    def execute(args)
      topic = Topic.where(id: args[:topic_id]).first
      if topic and topic.auto_close_at and !topic.closed? and !topic.deleted_at
        closer = User.where(id: args[:user_id]).first
        if Guardian.new(closer).can_moderate?(topic)
          topic.update_status('autoclosed', true, closer)
        end
      end
    end

  end
end
