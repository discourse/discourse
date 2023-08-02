# frozen_string_literal: true

module Jobs
  module Chat
    class AutoJoinChannelBatch < ServiceJob
      def execute(args)
        with_service(::Chat::AutoJoinChannelBatch, **args) do
          on_failed_contract do |contract|
            Rails.logger.error(contract.errors.full_messages.join(", "))
          end
          on_model_not_found(:channel) do
            Rails.logger.error("Channel not found (id=#{result.contract.channel_id})")
          end
        end
      end
    end
  end
end
