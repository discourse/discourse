module Jobs
  class CloseTopic < Jobs::Base

    def execute(args)
      if topic = Topic.where(id: args[:topic_id]).first
        closer = User.where(id: args[:user_id]).first
        topic.auto_close(closer)
      end
    end

  end
end
