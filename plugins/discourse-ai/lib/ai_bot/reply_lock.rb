# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ReplyLock
      def self.synchronize(key)
        held = Thread.current[:discourse_ai_reply_locks] ||= Set.new
        scope = [RailsMultisite::ConnectionManagement.current_db, key]
        # Tool callbacks can synchronously request another reply in this scope.
        return yield if held.include?(scope)

        DistributedMutex.synchronize(key, validity: 30.minutes) do
          held.add(scope)
          begin
            yield
          ensure
            held.delete(scope)
            Thread.current[:discourse_ai_reply_locks] = nil if held.empty?
          end
        end
      end
    end
  end
end
