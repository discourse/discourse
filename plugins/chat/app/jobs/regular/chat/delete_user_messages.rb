# frozen_string_literal: true

module Jobs
  module Chat
    class DeleteUserMessages < ::Jobs::Base
      def execute(args)
        return if args[:user_id].nil?

        ::Chat::MessageDestroyer.new.destroy_in_batches(
          ::Chat::Message.with_deleted.where(user_id: args[:user_id]),
        )
      end
    end
  end
end
