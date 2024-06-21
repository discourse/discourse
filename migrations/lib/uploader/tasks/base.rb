# frozen_string_literal: true

require "etc"
require "colored2"

module Migrations::Uploader
  module Tasks
    class Base
      class NotImplementedError < StandardError
      end

      TRANSACTION_SIZE = 1000
      QUEUE_SIZE = 1000

      attr_reader :uploads_db,
                  :intermediate_db,
                  :settings,
                  :work_queue,
                  :status_queue,
                  :discourse_store,
                  :consumer_threads

      def initialize(databases, settings)
        @uploads_db = databases[:uploads_db]
        @intermediate_db = databases[:intermediate_db]

        @settings = settings

        @work_queue = SizedQueue.new(QUEUE_SIZE)
        @status_queue = SizedQueue.new(QUEUE_SIZE)
        @discourse_store = Discourse.store
        @consumer_threads = []
      end

      def run!
        raise NotImplementedError
      end

      def add_multisite_prefix(path)
        return path if !Rails.configuration.multisite

        File.join("uploads", RailsMultisite::ConnectionManagement.current_db, path)
      end

      def thread_count
        @thread_count ||= (Etc.nprocessors * settings[:thread_count_factor] * 2).to_i
      end

      def self.run!(databases, settings)
        new(databases, settings).run!
      end
    end
  end
end
