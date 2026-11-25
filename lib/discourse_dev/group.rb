# frozen_string_literal: true

require "discourse_dev/record"
require "rails"
require "faker"

module DiscourseDev
  class Group < Record
    def initialize
      super(::Group, DiscourseDev.config.group[:count])
    end

    def data
      {
        name: Faker::Discourse.unique.group,
        public_exit: Faker::Boolean.boolean,
        public_admission: Faker::Boolean.boolean,
        primary_group: Faker::Boolean.boolean,
        created_at: Faker::Time.between(from: DiscourseDev.config.start_date, to: DateTime.now),
      }
    end

    def create!
      super do |group|
        if Faker::Boolean.boolean
          group.add_owner(::Discourse.system_user)
          group.allow_membership_requests = true
          group.save!
        end
      end
    end

    # Auto group rows (everyone, anonymous_users, logged_in_users, staff,
    # trust levels, ...) are implicit populations, not real groups; granting
    # them permissions or membership breaks validations and semantics.
    def self.random
      super(::Group.where.not(id: ::Group::AUTO_GROUPS.values))
    end
  end
end
