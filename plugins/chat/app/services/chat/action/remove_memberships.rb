# frozen_string_literal: true

module Chat
  module Action
    class RemoveMemberships < Service::ActionBase
      option :memberships

      def call
        memberships
          .destroy_all
          .each_with_object(Hash.new { |h, k| h[k] = [] }) do |obj, hash|
            hash[obj.chat_channel_id] << obj.user_id
          end
      end
    end
  end
end
