# frozen_string_literal: true

require "discourse_dev/record"
require "faker"

module DiscourseDev
  class DirectChannel < Record
    def initialize
      super(Chat::DirectMessage, 5)
    end

    def data
      if Faker::Boolean.boolean(true_ratio: 0.5)
        admin_username =
          begin
            DiscourseDev::Config.new.config[:admin][:username]
          rescue StandardError
            nil
          end
        admin_user = ::User.find_by(username: admin_username) if admin_username
      end

      [User.new.create!, admin_user || User.new.create!]
    end

    def create!
      users = data
      Chat::DirectMessageChannelCreator.create!(acting_user: users[0], target_users: users)
    end
  end
end
