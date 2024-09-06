# frozen_string_literal: true

module Action
  module User
    class TriggerPostAction
      attr_reader :guardian, :post, :contract

      delegate :post_action, to: :contract, private: true
      delegate :user, to: :guardian, private: true

      def initialize(guardian:, post:, contract:)
        @guardian, @post, @contract = guardian, post, contract
      end

      def self.call(...)
        new(...).call
      end

      def call
        return if post.blank? || post_action.blank?
        send(post_action)
      rescue NoMethodError
      end

      private

      def delete
        return unless guardian.can_delete_post_or_topic?(post)
        PostDestroyer.new(user, post).destroy
      end

      def delete_replies
        return unless guardian.can_delete_post_or_topic?(post)
        PostDestroyer.delete_with_replies(user, post)
      end

      def edit
        # Take what the moderator edited in as gospel
        PostRevisor.new(post).revise!(
          user,
          { raw: contract.post_edit },
          skip_validations: true,
          skip_revision: true,
        )
      end
    end
  end
end
