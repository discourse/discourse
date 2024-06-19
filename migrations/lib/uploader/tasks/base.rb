# frozen_string_literal: true

require "etc"

module Migrations::Uploader
  module Tasks
    class Base
      class NotImplementedError < StandardError
      end

      TRANSACTION_SIZE = 1000
      QUEUE_SIZE = 1000

      attr_reader :uploads_db, :intermediate_db, :settings

      def initialize(databases, settings)
        @uploads_db = databases[:uploads_db]
        @intermediate_db = databases[:intermediate_db]

        @settings = settings
      end

      def run!
        raise NotImplementedError
      end

      def self.run!(databases, settings)
        new(databases, settings).run!
      end
    end
  end
end
