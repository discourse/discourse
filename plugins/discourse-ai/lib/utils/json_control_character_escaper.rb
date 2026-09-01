# frozen_string_literal: true

require "strscan"

module DiscourseAi
  module Utils
    # Some providers return JSON with control characters unescaped inside string values.
    # Formatting whitespace outside strings must remain unchanged when repairing those values.
    # Instances retain lexical state and must be scoped to one JSON document.
    class JsonControlCharacterEscaper
      SPECIAL_CHARACTERS = /["\\\x00-\x1F]/
      private_constant :SPECIAL_CHARACTERS

      class << self
        def escape(json)
          new.escape(json)
        end
      end

      def initialize
        @inside_string = false
        @escaping_character = false
      end

      def escape(json)
        scanner = StringScanner.new(json)
        escaped = +""

        while (segment = scanner.scan_until(SPECIAL_CHARACTERS))
          character = segment.slice!(-1)
          if !segment.empty?
            escaped << segment
            @escaping_character = false
          end
          append_special_character(escaped, character)
        end

        if !scanner.rest.empty?
          escaped << scanner.rest
          @escaping_character = false
        end

        escaped
      end

      private

      def append_special_character(escaped, character)
        if !@inside_string
          escaped << character
          @inside_string = true if character == '"'
        elsif character.ord < 0x20
          escaped << format("\\u%04x", character.ord)
          @escaping_character = false
        else
          escaped << character
          if @escaping_character
            @escaping_character = false
          elsif character == "\\"
            @escaping_character = true
          elsif character == '"'
            @inside_string = false
          end
        end
      end
    end
  end
end
