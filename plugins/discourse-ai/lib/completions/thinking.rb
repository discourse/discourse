# frozen_string_literal: true

module DiscourseAi
  module Completions
    class Thinking
      attr_accessor :message, :partial
      attr_reader :provider_info

      def initialize(message:, partial: false, provider_info: {})
        @message = message
        @partial = partial
        self.provider_info = provider_info
      end

      def partial?
        !!@partial
      end

      def provider_info=(info)
        @provider_info = self.class.normalize_provider_info(info)
      end

      def provider_info_for(key)
        provider_info[key.to_sym]
      end

      def merge_provider_info!(info)
        @provider_info = self.class.merge_provider_info(@provider_info, info)
      end

      def serialized_provider_info
        self.class.deep_stringify_keys(provider_info)
      end

      def as_json(_opts = nil)
        { "message" => message, "provider_info" => serialized_provider_info }
      end

      def ==(other)
        message == other.message && partial == other.partial && provider_info == other.provider_info
      end

      def dup
        Thinking.new(message: message&.dup, partial: partial, provider_info: provider_info.deep_dup)
      end

      def to_s
        "#{message} - #{provider_info.inspect} - #{partial}"
      end

      def self.merge_provider_info(existing, incoming)
        normalize_provider_info(existing).deep_merge(normalize_provider_info(incoming))
      end

      def self.normalize_provider_info(info)
        return {} if info.blank?

        info.each_with_object({}) do |(key, value), memo|
          memo[normalize_key(key)] = normalize_value(value)
        end
      end

      def self.deep_stringify_keys(info)
        return {} if info.blank?

        info.each_with_object({}) do |(key, value), memo|
          memo[key.to_s] = if value.is_a?(Hash)
            deep_stringify_keys(value)
          elsif value.is_a?(Array)
            value.map { |item| item.is_a?(Hash) ? deep_stringify_keys(item) : item }
          else
            value
          end
        end
      end

      def self.normalize_key(key)
        key.is_a?(Symbol) ? key : key.to_sym
      rescue StandardError
        key
      end
      private_class_method :normalize_key

      def self.normalize_value(value)
        if value.is_a?(Hash)
          normalize_provider_info(value)
        elsif value.is_a?(Array)
          value.map { |item| item.is_a?(Hash) ? normalize_provider_info(item) : item }
        else
          value
        end
      end
      private_class_method :normalize_value
    end
  end
end
