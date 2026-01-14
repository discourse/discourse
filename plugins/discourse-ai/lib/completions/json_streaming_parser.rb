# frozen_string_literal: true

# This code is copied from the MIT licensed json-stream
# see: https://github.com/dgraham/json-stream
#
# It was copied to avoid the dependency and allow us to make some small changes
# particularly we need better access to internal state when parsing

module DiscourseAi
  module Completions
    # Raised on any invalid JSON text.
    ParserError = Class.new(RuntimeError)

    # A streaming JSON parser that generates SAX-like events for state changes.
    # Use the json gem for small documents. Use this for huge documents that
    # won't fit in memory.
    #
    # Examples
    #
    #   parser = JSON::Stream::Parser.new
    #   parser.key { |key| puts key }
    #   parser.value { |value| puts value }
    #   parser << '{"answer":'
    #   parser << ' 42}'
    class JsonStreamingParser
      # our changes:
      attr_reader :state, :buf, :pos

      # A character buffer that expects a UTF-8 encoded stream of bytes.
      # This handles truncated multi-byte characters properly so we can just
      # feed it binary data and receive a properly formatted UTF-8 String as
      # output.
      #
      # More UTF-8 parsing details are available at:
      #
      #   http://en.wikipedia.org/wiki/UTF-8
      #   http://tools.ietf.org/html/rfc3629#section-3
      class Buffer
        def initialize
          @state = :start
          @buffer = []
          @need = 0
        end

        # Fill the buffer with a String of binary UTF-8 encoded bytes. Returns
        # as much of the data in a UTF-8 String as we have. Truncated multi-byte
        # characters are saved in the buffer until the next call to this method
        # where we expect to receive the rest of the multi-byte character.
        #
        # data - The partial binary encoded String data.
        #
        # Raises JSON::Stream::ParserError if the UTF-8 byte sequence is malformed.
        #
        # Returns a UTF-8 encoded String.
        def <<(data)
          data = data.dup if data.frozen?
          # Avoid state machine for complete UTF-8.
          if @buffer.empty?
            data.force_encoding(Encoding::UTF_8)
            return data if data.valid_encoding?
          end

          bytes = []
          data.each_byte do |byte|
            case @state
            when :start
              if byte < 128
                bytes << byte
              elsif byte >= 192
                @state = :multi_byte
                @buffer << byte
                @need =
                  case
                  when byte >= 240
                    4
                  when byte >= 224
                    3
                  when byte >= 192
                    2
                  end
              else
                error("Expected start of multi-byte or single byte char")
              end
            when :multi_byte
              if byte > 127 && byte < 192
                @buffer << byte
                if @buffer.size == @need
                  bytes += @buffer.slice!(0, @buffer.size)
                  @state = :start
                end
              else
                error("Expected continuation byte")
              end
            end
          end

          # Build UTF-8 encoded string from completed codepoints.
          bytes
            .pack("C*")
            .force_encoding(Encoding::UTF_8)
            .tap { |text| error("Invalid UTF-8 byte sequence") unless text.valid_encoding? }
        end

        # Determine if the buffer contains partial UTF-8 continuation bytes that
        # are waiting on subsequent completion bytes before a full codepoint is
        # formed.
        #
        # Examples
        #
        #   bytes = "é".bytes
        #
        #   buffer << bytes[0]
        #   buffer.empty?
        #   # => false
        #
        #   buffer << bytes[1]
        #   buffer.empty?
        #   # => true
        #
        # Returns true if the buffer is empty.
        def empty?
          @buffer.empty?
        end

        private

        def error(message)
          raise ParserError, message
        end
      end

      BUF_SIZE = 4096
      CONTROL = /[\x00-\x1F]/
      WS = /[ \n\t\r]/
      HEX = /[0-9a-fA-F]/
      DIGIT = /[0-9]/
      DIGIT_1_9 = /[1-9]/
      DIGIT_END = /\d$/
      TRUE_RE = /[rue]/
      FALSE_RE = /[alse]/
      NULL_RE = /[ul]/
      TRUE_KEYWORD = "true"
      FALSE_KEYWORD = "false"
      NULL_KEYWORD = "null"
      LEFT_BRACE = "{"
      RIGHT_BRACE = "}"
      LEFT_BRACKET = "["
      RIGHT_BRACKET = "]"
      BACKSLASH = '\\'
      SLASH = "/"
      QUOTE = '"'
      COMMA = ","
      COLON = ":"
      ZERO = "0"
      MINUS = "-"
      PLUS = "+"
      POINT = "."
      EXPONENT = /[eE]/
      B, F, N, R, T, U = %w[b f n r t u]

      # Create a new parser with an optional initialization block where
      # we can register event callbacks.
      #
      # Examples
      #
      #   parser = JSON::Stream::Parser.new do
      #     start_document { puts "start document" }
      #     end_document   { puts "end document" }
      #     start_object   { puts "start object" }
      #     end_object     { puts "end object" }
      #     start_array    { puts "start array" }
      #     end_array      { puts "end array" }
      #     key            { |k| puts "key: #{k}" }
      #     value          { |v| puts "value: #{v}" }
      #   end
      def initialize(&block)
        @state = :start_document
        @utf8 = Buffer.new
        @listeners = {
          start_document: [],
          end_document: [],
          start_object: [],
          end_object: [],
          start_array: [],
          end_array: [],
          key: [],
          value: [],
        }

        # Track parse stack.
        @stack = []
        @unicode = +""
        @buf = +""
        @pos = -1

        # Register any observers in the block.
        instance_eval(&block) if block_given?
      end

      def start_document(&block)
        @listeners[:start_document] << block
      end

      def end_document(&block)
        @listeners[:end_document] << block
      end

      def start_object(&block)
        @listeners[:start_object] << block
      end

      def end_object(&block)
        @listeners[:end_object] << block
      end

      def start_array(&block)
        @listeners[:start_array] << block
      end

      def end_array(&block)
        @listeners[:end_array] << block
      end

      def key(&block)
        @listeners[:key] << block
      end

      def value(&block)
        @listeners[:value] << block
      end

      # Pass data into the parser to advance the state machine and
      # generate callback events. This is well suited for an EventMachine
      # receive_data loop.
      #
      # data - The String of partial JSON data to parse.
      #
      # Raises a JSON::Stream::ParserError if the JSON data is malformed.
      #
      # Returns nothing.
      def <<(data)
        (@utf8 << data).each_char do |ch|
          @pos += 1
          case @state
          when :start_document
            start_value(ch)
          when :start_object
            case ch
            when QUOTE
              @state = :start_string
              @stack.push(:key)
            when RIGHT_BRACE
              end_container(:object)
            when WS
              # ignore
            else
              error("Expected object key start")
            end
          when :start_string
            case ch
            when QUOTE
              if @stack.pop == :string
                end_value(@buf)
              else # :key
                @state = :end_key
                notify(:key, @buf)
              end
              @buf = +""
            when BACKSLASH
              @state = :start_escape
            when CONTROL
              error("Control characters must be escaped")
            else
              @buf << ch
            end
          when :start_escape
            case ch
            when QUOTE, BACKSLASH, SLASH
              @buf << ch
              @state = :start_string
            when B
              @buf << "\b"
              @state = :start_string
            when F
              @buf << "\f"
              @state = :start_string
            when N
              @buf << "\n"
              @state = :start_string
            when R
              @buf << "\r"
              @state = :start_string
            when T
              @buf << "\t"
              @state = :start_string
            when U
              @state = :unicode_escape
            else
              error("Expected escaped character")
            end
          when :unicode_escape
            case ch
            when HEX
              @unicode << ch
              if @unicode.size == 4
                codepoint = @unicode.slice!(0, 4).hex
                if codepoint >= 0xD800 && codepoint <= 0xDBFF
                  error("Expected low surrogate pair half") if @stack[-1].is_a?(Integer)
                  @state = :start_surrogate_pair
                  @stack.push(codepoint)
                elsif codepoint >= 0xDC00 && codepoint <= 0xDFFF
                  high = @stack.pop
                  error("Expected high surrogate pair half") unless high.is_a?(Integer)
                  pair = ((high - 0xD800) * 0x400) + (codepoint - 0xDC00) + 0x10000
                  @buf << pair
                  @state = :start_string
                else
                  @buf << codepoint
                  @state = :start_string
                end
              end
            else
              error("Expected unicode escape hex digit")
            end
          when :start_surrogate_pair
            case ch
            when BACKSLASH
              @state = :start_surrogate_pair_u
            else
              error("Expected low surrogate pair half")
            end
          when :start_surrogate_pair_u
            case ch
            when U
              @state = :unicode_escape
            else
              error("Expected low surrogate pair half")
            end
          when :start_negative_number
            case ch
            when ZERO
              @state = :start_zero
              @buf << ch
            when DIGIT_1_9
              @state = :start_int
              @buf << ch
            else
              error("Expected 0-9 digit")
            end
          when :start_zero
            case ch
            when POINT
              @state = :start_float
              @buf << ch
            when EXPONENT
              @state = :start_exponent
              @buf << ch
            else
              end_value(@buf.to_i)
              @buf = +""
              @pos -= 1
              redo
            end
          when :start_float
            case ch
            when DIGIT
              @state = :in_float
              @buf << ch
            else
              error("Expected 0-9 digit")
            end
          when :in_float
            case ch
            when DIGIT
              @buf << ch
            when EXPONENT
              @state = :start_exponent
              @buf << ch
            else
              end_value(@buf.to_f)
              @buf = +""
              @pos -= 1
              redo
            end
          when :start_exponent
            case ch
            when MINUS, PLUS, DIGIT
              @state = :in_exponent
              @buf << ch
            else
              error("Expected +, -, or 0-9 digit")
            end
          when :in_exponent
            case ch
            when DIGIT
              @buf << ch
            else
              error("Expected 0-9 digit") unless @buf =~ DIGIT_END
              end_value(@buf.to_f)
              @buf = +""
              @pos -= 1
              redo
            end
          when :start_int
            case ch
            when DIGIT
              @buf << ch
            when POINT
              @state = :start_float
              @buf << ch
            when EXPONENT
              @state = :start_exponent
              @buf << ch
            else
              end_value(@buf.to_i)
              @buf = +""
              @pos -= 1
              redo
            end
          when :start_true
            keyword(TRUE_KEYWORD, true, TRUE_RE, ch)
          when :start_false
            keyword(FALSE_KEYWORD, false, FALSE_RE, ch)
          when :start_null
            keyword(NULL_KEYWORD, nil, NULL_RE, ch)
          when :end_key
            case ch
            when COLON
              @state = :key_sep
            when WS
              # ignore
            else
              error("Expected colon key separator")
            end
          when :key_sep
            start_value(ch)
          when :start_array
            case ch
            when RIGHT_BRACKET
              end_container(:array)
            when WS
              # ignore
            else
              start_value(ch)
            end
          when :end_value
            case ch
            when COMMA
              @state = :value_sep
            when RIGHT_BRACE
              end_container(:object)
            when RIGHT_BRACKET
              end_container(:array)
            when WS
              # ignore
            else
              error("Expected comma or object or array close")
            end
          when :value_sep
            if @stack[-1] == :object
              case ch
              when QUOTE
                @state = :start_string
                @stack.push(:key)
              when WS
                # ignore
              else
                error("Expected object key start")
              end
            else
              start_value(ch)
            end
          when :end_document
            error("Unexpected data") unless ch =~ WS
          end
        end
      end

      # Drain any remaining buffered characters into the parser to complete
      # the parsing of the document.
      #
      # This is only required when parsing a document containing a single
      # numeric value, integer or float. The parser has no other way to
      # detect when it should no longer expect additional characters with
      # which to complete the parse, so it must be signaled by a call to
      # this method.
      #
      # If you're parsing more typical object or array documents, there's no
      # need to call `finish` because the parse will complete when the final
      # closing `]` or `}` character is scanned.
      #
      # Raises a JSON::Stream::ParserError if the JSON data is malformed.
      #
      # Returns nothing.
      def finish
        # Partial multi-byte character waiting for completion bytes.
        error("Unexpected end-of-file") unless @utf8.empty?

        # Partial array, object, or string.
        error("Unexpected end-of-file") unless @stack.empty?

        case @state
        when :end_document
          # done, do nothing
        when :in_float
          end_value(@buf.to_f)
        when :in_exponent
          error("Unexpected end-of-file") unless @buf =~ DIGIT_END
          end_value(@buf.to_f)
        when :start_zero
          end_value(@buf.to_i)
        when :start_int
          end_value(@buf.to_i)
        else
          error("Unexpected end-of-file")
        end
      end

      private

      # Invoke all registered observer procs for the event type.
      #
      # type - The Symbol listener name.
      # args - The argument list to pass into the observer procs.
      #
      # Examples
      #
      #    # broadcast events for {"answer": 42}
      #    notify(:start_object)
      #    notify(:key, "answer")
      #    notify(:value, 42)
      #    notify(:end_object)
      #
      # Returns nothing.
      def notify(type, *args)
        @listeners[type].each { |block| block.call(*args) }
      end

      # Complete an object or array container value type.
      #
      # type - The Symbol, :object or :array, of the expected type.
      #
      # Raises a JSON::Stream::ParserError if the expected container type
      #   was not completed.
      #
      # Returns nothing.
      def end_container(type)
        @state = :end_value
        if @stack.pop == type
          case type
          when :object
            notify(:end_object)
          when :array
            notify(:end_array)
          end
        else
          error("Expected end of #{type}")
        end
        notify_end_document if @stack.empty?
      end

      # Broadcast an `end_document` event to observers after a complete JSON
      # value document (object, array, number, string, true, false, null) has
      # been parsed from the text. This is the final event sent to observers
      # and signals the parse has finished.
      #
      # Returns nothing.
      def notify_end_document
        @state = :end_document
        notify(:end_document)
      end

      # Parse one of the three allowed keywords: true, false, null.
      #
      # word  - The String keyword ('true', 'false', 'null').
      # value - The Ruby value (true, false, nil).
      # re    - The Regexp of allowed keyword characters.
      # ch    - The current String character being parsed.
      #
      # Raises a JSON::Stream::ParserError if the character does not belong
      #   in the expected keyword.
      #
      # Returns nothing.
      def keyword(word, value, re, ch)
        if ch =~ re
          @buf << ch
        else
          error("Expected #{word} keyword")
        end

        if @buf.size == word.size
          if @buf == word
            @buf = +""
            end_value(value)
          else
            error("Expected #{word} keyword")
          end
        end
      end

      # Process the first character of one of the seven possible JSON
      # values: object, array, string, true, false, null, number.
      #
      # ch - The current character String.
      #
      # Raises a JSON::Stream::ParserError if the character does not signal
      #   the start of a value.
      #
      # Returns nothing.
      def start_value(ch)
        case ch
        when LEFT_BRACE
          notify(:start_document) if @stack.empty?
          @state = :start_object
          @stack.push(:object)
          notify(:start_object)
        when LEFT_BRACKET
          notify(:start_document) if @stack.empty?
          @state = :start_array
          @stack.push(:array)
          notify(:start_array)
        when QUOTE
          @state = :start_string
          @stack.push(:string)
        when T
          @state = :start_true
          @buf << ch
        when F
          @state = :start_false
          @buf << ch
        when N
          @state = :start_null
          @buf << ch
        when MINUS
          @state = :start_negative_number
          @buf << ch
        when ZERO
          @state = :start_zero
          @buf << ch
        when DIGIT_1_9
          @state = :start_int
          @buf << ch
        when WS
          # ignore
        else
          error("Expected value")
        end
      end

      # Advance the state machine and notify `value` observers that a
      # string, number or keyword (true, false, null) value was parsed.
      #
      # value - The object to broadcast to observers.
      #
      # Returns nothing.
      def end_value(value)
        @state = :end_value
        notify(:start_document) if @stack.empty?
        notify(:value, value)
        notify_end_document if @stack.empty?
      end

      def error(message)
        raise ParserError, "#{message}: char #{@pos}"
      end
    end
  end
end
