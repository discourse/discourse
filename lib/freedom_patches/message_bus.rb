# frozen_string_literal: true

require 'redis'
require 'digest'

require "message_bus/backends/base"

# Pull request describing this fix - https://github.com/SamSaffron/message_bus/pull/214

module MessageBus
  module Backends
    class Redis < Base
      private

      def new_redis_connection
        ::Redis.new(@redis_config.dup)
      end
    end
  end
end
