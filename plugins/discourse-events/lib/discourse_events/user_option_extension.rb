# frozen_string_literal: true

module DiscourseEvents
  module UserOptionExtension
    def self.prepended(base)
      unless base.method_defined?(:event_reminder_preference_notification?)
        # Allow model annotation after the column's migration is rolled back.
        base.attribute :event_reminder_preference, :integer
        base.enum :event_reminder_preference,
                  { notification: 0, email: 1, both: 2, none: 3 },
                  prefix: true,
                  scopes: false,
                  validate: true
      end
    end
  end
end
