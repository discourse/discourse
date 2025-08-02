# frozen_string_literal: true

require "discourse_dev/reviewable"
require "faker"

module DiscourseDev
  class ReviewableFlaggedPost < Reviewable
    def populate!
      types = PostActionType.notify_flag_types.keys

      posts = @posts.sample(types.size + 1)
      users = @users.sample(types.size + 3)

      types.each do |type|
        post = posts.pop
        user = users.pop

        reason = nil

        reason = Faker::Lorem.paragraph if type == :notify_moderators

        PostActionCreator.create(user, post, type, reason:)
      end

      posts.pop.tap do |post|
        type = types.excluding(:notify_moderators).sample
        3.times do
          user = users.pop

          PostActionCreator.create(user, post, type)
        end
      end
    end
  end
end
