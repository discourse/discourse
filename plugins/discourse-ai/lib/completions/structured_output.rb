# frozen_string_literal: true

module DiscourseAi
  module Completions
    class StructuredOutput
      def initialize(json_schema_properties)
        @property_names = json_schema_properties.keys.map(&:to_sym)
        @property_cursors =
          json_schema_properties.reduce({}) do |m, (k, prop)|
            m[k.to_sym] = 0 if prop[:type] == "string"
            m
          end

        @tracked = {}

        @raw_response = +""
        @raw_cursor = 0

        @partial_json_tracker = JsonStreamingTracker.new(self)

        @type_map = {}
        json_schema_properties.each { |name, prop| @type_map[name.to_sym] = prop[:type].to_sym }

        @done = false
      end

      def to_s
        # we may want to also normalize the JSON here for the broken case
        @raw_response.to_s
      end

      # require for any implicity string conversions
      def to_str
        to_s
      end

      attr_reader :last_chunk_buffer

      def <<(raw)
        raise "Cannot append to a completed StructuredOutput" if @done
        @raw_response << raw
        @partial_json_tracker << raw
      end

      def finish
        @done = true
      end

      def finished?
        @done
      end

      def broken?
        @partial_json_tracker.broken?
      end

      def read_buffered_property(prop_name)
        if @partial_json_tracker.broken?
          if @done
            return nil if @type_map[prop_name.to_sym].nil?
            return(
              DiscourseAi::Utils::BestEffortJsonParser.extract_key(
                @raw_response,
                @type_map[prop_name.to_sym],
                prop_name,
              )
            )
          else
            return nil
          end
        end

        # Maybe we haven't read that part of the JSON yet.
        return nil if @tracked[prop_name].nil?

        # This means this property is a string and we want to return unread chunks.
        if @property_cursors[prop_name].present?
          unread = @tracked[prop_name][@property_cursors[prop_name]..]
          @property_cursors[prop_name] = @tracked[prop_name].length
          unread
        else
          # Ints and bools, and arrays are always returned as is.
          @tracked[prop_name]
        end
      end

      def notify_progress(key, value)
        key_sym = key.to_sym
        return if !@property_names.include?(key_sym)

        @tracked[key_sym] = value
      end
    end
  end
end
