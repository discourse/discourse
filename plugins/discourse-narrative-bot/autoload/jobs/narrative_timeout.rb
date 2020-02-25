# frozen_string_literal: true

module Jobs
  class NarrativeTimeout < ::Jobs::Base
    def execute(args)
      if user = User.find_by(id: args[:user_id])
        I18n.with_locale(user.effective_locale) do
          args[:klass].constantize.new.notify_timeout(user)
        end
      end
    end
  end
end
