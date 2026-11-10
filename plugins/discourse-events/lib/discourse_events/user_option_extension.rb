# frozen_string_literal: true

module DiscourseEvents
  module UserOptionExtension
    def self.prepended(base)
      unless base.method_defined?(:event_reminder_preference_personal_message?)
        # Allow model annotation after the column's migration is rolled back.
        base.attribute :event_reminder_preference, :integer
        base.enum :event_reminder_preference,
                  { personal_message: 0, none: 1, notification: 2 },
                  prefix: true,
                  scopes: false,
                  validate: true
      end
    end
  end
end
