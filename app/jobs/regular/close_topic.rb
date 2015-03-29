module Jobs
  class CloseTopic < Jobs::Base

    def execute(args)
      if topic = Topic.find_by(id: args[:topic_id])
        closer = User.find_by(id: args[:user_id])
        topic.auto_close(closer)
      end
    end

  end
end
