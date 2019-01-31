require_dependency 'score_calculator'

module Jobs

  # This job will run on a regular basis to update statistics and denormalized data.
  # If it does not run, the site will not function properly.
  class PeriodicalUpdates < Jobs::Scheduled
    every 15.minutes

    def self.should_update_long_topics?
      @call_count ||= 0
      @call_count += 1

      # once every 6 hours
      (@call_count % 24) == 1
    end

    def execute(args = nil)
      # Feature topics in categories
      CategoryFeaturedTopic.feature_topics(batched: true)

      # Update the scores of posts
      args = { min_topic_age: 1.day.ago }
      args[:max_topic_length] = 500 unless self.class.should_update_long_topics?
      ScoreCalculator.new.calculate(args)

      # Re-run stuff that we missed
      TopicTimer.ensure_consistency!

      # Forces rebake of old posts where needed, as long as no system avatars need updating
      if !SiteSetting.automatically_download_gravatars || !UserAvatar.where("last_gravatar_download_attempt IS NULL").limit(1).first
        problems = Post.rebake_old(SiteSetting.rebake_old_posts_count, priority: :ultra_low)
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

      offset = (SiteSetting.max_new_topics).to_i
      last_new_topic = Topic.order('created_at desc').offset(offset).select(:created_at).first
      if last_new_topic
        SiteSetting.min_new_topics_time = last_new_topic.created_at.to_i
      end

      Category.auto_bump_topic!

      nil
    end

  end

end
