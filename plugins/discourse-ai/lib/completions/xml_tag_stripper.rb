# frozen_string_literal: true

module DiscourseAi
  module Completions
    class XmlTagStripper
      def initialize(tags_to_strip)
        @tags_to_strip = tags_to_strip
        @tags_set = tags_to_strip.to_h { |tag| [tag, true] }.freeze
        @longest_tag = tags_to_strip.map(&:length).max || 0
        @open_tag = nil
        @hidden_buffer = +""
        @maybe_tag = nil
      end

      def <<(text)
        if @maybe_tag
          text = @maybe_tag + text
          @maybe_tag = nil
        end

        output = +""
        pos = 0
        len = text.length

        while pos < len
          lt = text.index("<", pos)
          if lt.nil?
            chunk = pos == 0 ? text : text[pos, len - pos]
            if @open_tag
              @hidden_buffer << chunk
            else
              output << chunk
            end
            break
          end

          if lt > pos
            before = text[pos, lt - pos]
            if @open_tag
              @hidden_buffer << before
            else
              output << before
            end
          end

          if lt == len - 1
            @maybe_tag = "<"
            break
          end

          gt = text.index(">", lt + 1)
          if gt.nil?
            tag = text[lt + 1, len - lt - 1]
            tag_name = tag.start_with?("/") ? (tag[1..] || "") : tag
            if tag_name.length <= @longest_tag &&
                 @tags_to_strip.any? { |tag_to_strip| tag_to_strip.start_with?(tag_name) }
              @maybe_tag = text[lt, len - lt]
            else
              raw = text[lt, len - lt]
              if @open_tag
                @hidden_buffer << raw
              else
                output << raw
              end
            end
            break
          end

          tag = text[lt + 1, gt - lt - 1]
          raw_tag = text[lt, gt - lt + 1]
          is_end_tag = tag.start_with?("/")
          tag_name = is_end_tag ? (tag[1..] || "") : tag

          if @tags_set[tag_name]
            if is_end_tag
              if @open_tag.nil?
                output << raw_tag
              elsif @open_tag == tag_name
                @open_tag = nil
                @hidden_buffer.clear
              else
                @hidden_buffer << raw_tag
              end
            else
              @open_tag ||= tag_name
              @hidden_buffer << raw_tag
            end
          else
            if @open_tag
              @hidden_buffer << raw_tag
            else
              output << raw_tag
            end
          end

          pos = gt + 1
        end

        output.empty? ? nil : output
      end

      def finish
        result = +""
        result << @hidden_buffer if !@hidden_buffer.empty?
        result << @maybe_tag if @maybe_tag
        result
      end

      def finish_visible
        return "" if @open_tag

        @maybe_tag || ""
      end
    end
  end
end
