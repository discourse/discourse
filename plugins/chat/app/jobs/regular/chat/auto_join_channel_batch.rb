# frozen_string_literal: true

module Jobs
  module Chat
    class AutoJoinChannelBatch < ::Jobs::Base
      def execute(params)
        ::Chat::AutoJoinChannelBatch.call(params:) do
          on_failure { Rails.logger.error("Failed with unexpected error") }
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
