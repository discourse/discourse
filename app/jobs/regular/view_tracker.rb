module Jobs

  # Asynchronously send an email to a user
  class ViewTracker < Jobs::Base
    def execute(args)
      topic_id = args[:topic_id]
      user_id = args[:user_id]
      ip = args[:ip]
      track_visit = args[:track_visit]

      View.create_for_parent(Topic, topic_id, ip, user_id)
      if track_visit
        TopicUser.track_visit! topic_id, user_id
      end
    end
  end
end
