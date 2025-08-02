# frozen_string_literal: true

module DiscourseAi
  module Completions
    class Thinking
      attr_accessor :message, :signature, :redacted, :partial

      def initialize(message:, signature: nil, redacted: false, partial: false)
        @message = message
        @signature = signature
        @redacted = redacted
        @partial = partial
      end

      def partial?
        !!@partial
      end

      def ==(other)
        message == other.message && signature == other.signature && redacted == other.redacted &&
          partial == other.partial
      end

      def dup
        Thinking.new(
          message: message.dup,
          signature: signature.dup,
          redacted: redacted,
          partial: partial,
        )
      end

      def to_s
        "#{message} - #{signature} - #{redacted} - #{partial}"
      end
    end
  end
end
