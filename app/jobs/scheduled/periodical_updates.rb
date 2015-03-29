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
          Discourse.handle_job_exception(hash[:ex], error_context(args, "Rebaking post id #{hash[:post].id}", post_id: hash[:post].id))
        end
      end

      # rebake out of date user profiles
      problems = UserProfile.rebake_old(250)
      problems.each do |hash|
        user_id = hash[:profile].user_id
        Discourse.handle_job_exception(hash[:ex], error_context(args, "Rebaking user id #{user_id}", user_id: user_id))
      end
    end

  end

end
