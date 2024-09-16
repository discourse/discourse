# frozen_string_literal: true

module Action
  module User
    class SuspendAll
      attr_reader :users, :actor, :contract

      delegate :message, :post_id, :suspend_until, :reason, to: :contract, private: true

      def initialize(users:, actor:, contract:)
        @users, @actor, @contract = users, actor, contract
      end

      def self.call(...)
        new(...).call
      end

      def call
        suspended_users.first.try(:user_history).try(:details)
      end

      private

      def suspended_users
        users.map do |user|
          UserSuspender.new(
            user,
            suspended_till: suspend_until,
            reason: reason,
            by_user: actor,
            message: message,
            post_id: post_id,
          ).tap(&:suspend)
        rescue => err
          Discourse.warn_exception(err, message: "failed to suspend user with ID #{user.id}")
        end
      end
    end
  end
end
