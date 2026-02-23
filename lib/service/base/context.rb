# frozen_string_literal: true

module Service
  module Base
    # Simple structure to hold the context of the service during its whole lifecycle.
    class Context
      delegate :slice, :dig, to: :store

      def self.build(context = {})
        self === context ? context : new(context)
      end

      def initialize(context = {})
        @store = context.symbolize_keys
      end

      def [](key)
        store[key.to_sym]
      end

      def []=(key, value)
        store[key.to_sym] = value
      end

      def to_h
        store.dup
      end

      # @return [Boolean] returns +true+ if the context is set as successful (default)
      def success?
        !failure?
      end

      # @return [Boolean] returns +true+ if the context is set as failed
      # @see #fail!
      # @see #fail
      def failure?
        @failure || false
      end

      # Marks the context as failed.
      # @param context [Hash, Context] the context to merge into the current one
      # @example
      #   context.fail!("failure": "something went wrong")
      # @return [Context]
      def fail!(context = {})
        self.fail(context)
        raise Failure, self
      end

      # Marks the context as failed without raising an exception.
      # @param context [Hash, Context] the context to merge into the current one
      # @example
      #   context.fail("failure": "something went wrong")
      # @return [Context]
      def fail(context = {})
        store.merge!(context.symbolize_keys)
        @failure = true
        self
      end

      def inspect_steps
        Service::StepsInspector.new(self).inspect
      end

      private

      attr_reader :store

      def method_missing(method_name, *args, &block)
        return super if args.present?
        store[method_name]
      end

      def respond_to_missing?(name, include_all)
        store.key?(name) || super
      end
    end
  end
end
