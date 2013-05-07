module Jobs
  class CloseTopic < Jobs::Base

    def execute(args)
      topic = Topic.find(args[:topic_id])
      if topic.auto_close_at
        closer = User.find(args[:user_id])
        if Guardian.new(closer).can_moderate?(topic)
          topic.update_status('autoclosed', true, closer)
        end
      end
    end

  end
end
