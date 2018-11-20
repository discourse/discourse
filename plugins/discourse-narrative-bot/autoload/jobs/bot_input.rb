module Jobs
  class BotInput < Jobs::Base

    sidekiq_options queue: 'critical', retry: false

    def execute(args)
      return unless user = User.find_by(id: args[:user_id])

      I18n.with_locale(user.effective_locale) do
        ::DiscourseNarrativeBot::TrackSelector.new(args[:input].to_sym, user,
          post_id: args[:post_id],
          topic_id: args[:topic_id]
        ).select
      end
    end
  end
end
