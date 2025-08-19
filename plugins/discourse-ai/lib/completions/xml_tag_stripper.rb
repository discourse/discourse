# frozen_string_literal: true

module DiscourseAi
  module Completions
    class XmlTagStripper
      def initialize(tags_to_strip)
        @tags_to_strip = tags_to_strip
        @longest_tag = tags_to_strip.map(&:length).max
        @parsed = []
      end

      def <<(text)
        if node = @parsed[-1]
          if node[:type] == :maybe_tag
            @parsed.pop
            text = node[:content] + text
          end
        end
        @parsed.concat(parse_tags(text))

        @parsed, result = process_parsed(@parsed)
        result
      end

      def finish
        @parsed.map { |node| node[:content] }.join
      end

      def process_parsed(parsed)
        output = []
        buffer = []
        stack = []

        parsed.each do |node|
          case node[:type]
          when :text
            if stack.empty?
              output << node[:content]
            else
              buffer << node
            end
          when :open_tag
            stack << node[:name]
            buffer << node
          when :close_tag
            if stack.empty?
              output << node[:content]
            else
              if stack[0] == node[:name]
                buffer = []
                stack = []
              else
                buffer << node
              end
            end
          when :maybe_tag
            buffer << node
          end
        end

        result = output.join
        result = nil if result.empty?

        [buffer, result]
      end

      def parse_tags(text)
        parsed = []

        while true
          before, after = text.split("<", 2)

          parsed << { type: :text, content: before } if before && !before.empty?

          break if after.nil?

          if before.empty? && after.empty?
            parsed << { type: :maybe_tag, content: "<" }
            break
          end

          tag, after = after.split(">", 2)

          is_end_tag = tag[0] == "/"
          tag_name = tag
          tag_name = tag[1..-1] || "" if is_end_tag

          if !after
            found = false
            if tag_name.length <= @longest_tag
              @tags_to_strip.each do |tag_to_strip|
                if tag_to_strip.start_with?(tag_name)
                  parsed << { type: :maybe_tag, content: "<" + tag }
                  found = true
                  break
                end
              end
            end
            parsed << { type: :text, content: "<" + tag } if !found
            break
          end

          raw_tag = "<" + tag + ">"

          if @tags_to_strip.include?(tag_name)
            parsed << {
              type: is_end_tag ? :close_tag : :open_tag,
              content: raw_tag,
              name: tag_name,
            }
          else
            parsed << { type: :text, content: raw_tag }
          end
          text = after
        end

        parsed
      end
    end
  end
end
