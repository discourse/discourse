# frozen_string_literal: true

module Chat
  module Service
    module Actions
      class RemoveMemberships
        def self.call(memberships:)
          memberships
            .destroy_all
            .each_with_object(Hash.new { |h, k| h[k] = [] }) do |obj, hash|
              hash[obj.chat_channel_id] << obj.user_id
            end
        end
      end
    end
  end
end
