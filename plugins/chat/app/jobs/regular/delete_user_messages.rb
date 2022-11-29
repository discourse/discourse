# frozen_string_literal: true

module Jobs
  class DeleteUserMessages < ::Jobs::Base
    def execute(args)
      return if args[:user_id].nil?

      ChatMessageDestroyer.new
        .destroy_in_batches(ChatMessage.with_deleted.where(user_id: args[:user_id]))
    end
  end
end
