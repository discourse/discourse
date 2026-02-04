# frozen_string_literal: true

require "cgi"

module Migrations::Converters::Phpbb3
  class TextProcessor
    def initialize(phpbb_config: {}, settings: {})
      @phpbb_config = phpbb_config
      @settings = settings
      @phpbb_version = phpbb_config[:phpbb_version] || "3.0.0"
      @use_xml_format = @phpbb_version.start_with?("3.2") || @phpbb_version.start_with?("3.3")
    end

    def process_post(raw, bbcode_uid = nil)
      return "" if raw.blank?

      if @use_xml_format
        process_xml_format(raw)
      else
        process_bbcode_format(raw, bbcode_uid)
      end
    rescue StandardError
      raw
    end

    def process_private_message(raw, bbcode_uid = nil)
      process_post(raw, bbcode_uid)
    end

    private

    def process_xml_format(raw)
      processed = raw.dup

      processed = decode_html_entities(processed)
      processed = convert_basic_formatting(processed)
      processed = convert_quotes(processed)
      processed = convert_code_blocks(processed)
      processed = convert_lists(processed)
      processed = convert_links(processed)
      processed = convert_images(processed)
      processed = clean_up(processed)

      processed
    end

    def process_bbcode_format(raw, bbcode_uid)
      processed = raw.dup

      processed.gsub!(/:#{Regexp.escape(bbcode_uid)}([\]\:])/, '\1') if bbcode_uid.present?

      processed = decode_html_entities(processed)
      processed = clean_bbcode_hashes(processed)
      processed = convert_basic_formatting(processed)
      processed = convert_quotes(processed)
      processed = convert_code_blocks(processed)
      processed = convert_lists(processed)
      processed = convert_links(processed)
      processed = convert_images(processed)
      processed = clean_up(processed)

      processed
    end

    def decode_html_entities(text)
      CGI.unescapeHTML(text)
    end

    def clean_bbcode_hashes(text)
      text.gsub(/:\w{5,8}\]/, "]")
    end

    def convert_basic_formatting(text)
      text
        .gsub(%r{\[b\](.*?)\[/b\]}mi, '**\1**')
        .gsub(%r{\[i\](.*?)\[/i\]}mi, '*\1*')
        .gsub(%r{\[u\](.*?)\[/u\]}mi, '\1')
        .gsub(%r{\[s\](.*?)\[/s\]}mi, '~~\1~~')
        .gsub(%r{\[size=\d+\](.*?)\[/size\]}mi, '\1')
        .gsub(%r{\[/?color(=#?[a-z0-9]*)?\]}i, "")
    end

    def convert_quotes(text)
      text
        .gsub(/\[quote="([^"]+)".*?\]/mi, "[quote=\"\\1\"]\n")
        .gsub(/\[quote\]/mi, "[quote]\n")
        .gsub(%r{\[/quote\]}mi, "\n[/quote]\n")
    end

    def convert_code_blocks(text)
      text.gsub(%r{\[code\](.*?)\[/code\]}mi) do
        code = Regexp.last_match(1)
        "\n```\n#{code.strip}\n```\n"
      end
    end

    def convert_lists(text)
      text
        .gsub(%r{\[list\](.*?)\[/list:u\]}mi) do
          items = Regexp.last_match(1)
          items.gsub(%r{\[\*\](.*?)\[/\*:m\]\n*}mi) { "* #{Regexp.last_match(1).strip}\n" }
        end
        .gsub(%r{\[list=\d*\](.*?)\[/list:o\]}mi) do
          items = Regexp.last_match(1)
          items.gsub(%r{\[\*\](.*?)\[/\*:m\]\n*}mi) { "1. #{Regexp.last_match(1).strip}\n" }
        end
        .gsub(%r{\[list\](.*?)\[/list\]}mi) do
          items = Regexp.last_match(1)
          items.gsub(%r{\[\*\](.*?)(?=\[\*\]|\[/list\])}mi) { "* #{Regexp.last_match(1).strip}\n" }
        end
    end

    def convert_links(text)
      text.gsub(%r{\[url=([^\]]+)\](.*?)\[/url\]}mi, '[\2](\1)').gsub(
        %r{\[url\](.*?)\[/url\]}mi,
        '\1',
      )
    end

    def convert_images(text)
      text.gsub(%r{\[img\](.*?)\[/img\]}mi, '![](\1)')
    end

    def clean_up(text)
      text.gsub(%r{<br\s*/?>}i, "\n").gsub(/\n{3,}/, "\n\n").strip
    end
  end
end
