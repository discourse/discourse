# frozen_string_literal: true

module Jobs
  class NarrativeInit < ::Jobs::Base
    sidekiq_options queue: "critical"

    def execute(args)
      if user = User.find_by(id: args[:user_id])
        I18n.with_locale(user.effective_locale) { args[:klass].constantize.new.input(:init, user) }
      end
    end
  end
end
