require_dependency 'score_calculator'

module Jobs

  # This job will run on a regular basis to update statistics and denormalized data.
  # If it does not run, the site will not function properly.
  class PeriodicalUpdates < Jobs::Scheduled
    every 15.minutes

    def execute(args)
      # Feature topics in categories
      CategoryFeaturedTopic.feature_topics

      # Update the scores of posts
      ScoreCalculator.new.calculate(1.day.ago)

      # Automatically close stuff that we missed
      Topic.auto_close

      # Forces rebake of old posts where needed, as long as no system avatars need updating
      unless UserAvatar.where("last_gravatar_download_attempt IS NULL").limit(1).first
        problems = Post.rebake_old(250)
        problems.each do |hash|
          post_id = hash[:post].id
          Discourse.handle_job_exception(hash[:ex], error_context(args, "Rebaking post id #{post_id}", post_id: post_id))
        end
      end

      # rebake out of date user profiles
      problems = UserProfile.rebake_old(250)
      problems.each do |hash|
        user_id = hash[:profile].user_id
        Discourse.handle_job_exception(hash[:ex], error_context(args, "Rebaking user id #{user_id}", user_id: user_id))
      end

      TopicUser.cap_unread_backlog!

      offset = (SiteSetting.max_tracked_new_unread * (2/5.0)).to_i
      last_new_topic = Topic.order('created_at desc').offset(offset).select(:created_at).first
      if last_new_topic
        SiteSetting.min_new_topics_time = last_new_topic.created_at.to_i
      end

      nil
    end

  end

end
