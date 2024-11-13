# frozen_string_literal: true

require "discourse_dev/record"
require "faker"

module DiscourseDev
  class CategoryChannel < Record
    def initialize(ignore_current_count: true, count: 5, channel_id: nil)
      super(::Chat::CategoryChannel, count)
    end

    def data
      chatable = Category.random
      description = Faker::Lorem.sentence
      name = Faker::Company.name
      created_at = Faker::Time.between(from: DiscourseDev.config.start_date, to: DateTime.now)

      { chatable:, description:, user_count: 1, name:, created_at: }
    end

    def create!
      users = []
      super do |channel|
        Faker::Number
          .between(from: 5, to: 10)
          .times do
            if Faker::Boolean.boolean(true_ratio: 0.5)
              admin_username =
                begin
                  DiscourseDev.config.admin[:username]
                rescue StandardError
                  nil
                end
              admin_user = ::User.find_by_username(admin_username) if admin_username
            end

            user =
              admin_user ||
                ::User.create!(
                  email: Faker::Internet.email,
                  username: Faker::Internet.username(specifier: 10),
                )
            Chat::ChannelMembershipManager.new(channel).follow(user)
            users << user
          end

        Faker::Number
          .between(from: 20, to: 80)
          .times do
            Chat::CreateMessage.call(
              guardian: users.sample.guardian,
              params: {
                chat_channel_id: channel.id,
                message: Faker::Lorem.sentence,
              },
            )
          end
      end
    end
  end
end
