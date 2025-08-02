# frozen_string_literal: true

class PlainTextToMarkdown
  SIGNATURE_SEPARATOR = "-- "

  def initialize(plaintext, opts = {})
    @plaintext = plaintext
    @lines = []

    @format_flowed = opts[:format_flowed] || false
    @delete_flowed_space = opts[:delete_flowed_space] || false
  end

  def to_markdown
    prepare_lines
    classify_lines

    markdown = +""
    last_quote_level = 0
    last_line_blank = false

    @lines.each do |line|
      current_line_blank = line.text.blank?

      unless last_line_blank && current_line_blank
        if line.quote_level > 0
          quote_identifiers = ">" * line.quote_level
          unless line.quote_level >= last_quote_level || current_line_blank
            markdown << quote_identifiers << "\n"
          end
          markdown << quote_identifiers
          markdown << " " unless current_line_blank
        else
          markdown << "\n" unless last_quote_level == 0 || current_line_blank
        end

        markdown << convert_text(line)
        markdown << "\n"
      end

      last_line_blank = current_line_blank
      last_quote_level = line.quote_level
    end

    markdown.rstrip!
    markdown
  end

  private

  class CodeBlock < Struct.new(:start_line, :end_line)
    def initialize(start_line, end_line = nil)
      super
    end

    def valid?
      start_line.present? && end_line.present?
    end
  end

  class Line < Struct.new(:text, :quote_level, :code_block)
    def initialize(text, quote_level = 0, code_block = nil)
      super
    end

    def valid_code_block?
      code_block&.valid?
    end
  end

  def prepare_lines
    previous_line = nil

    @plaintext.each_line do |text|
      text.chomp!
      line = Line.new(text)

      remove_quote_level_indicators!(line)

      if @format_flowed
        line = merge_lines(line, previous_line)
        @lines << line unless line == previous_line
      else
        @lines << line
      end

      previous_line = line
    end
  end

  def classify_lines
    previous_line = nil

    @lines.each do |line|
      classify_line_as_code!(line, previous_line)

      previous_line = line
    end
  end

  # @param line [Line]
  def remove_quote_level_indicators!(line)
    match_data = line.text.match(/\A(?<indicators>>+)\s?(?<text>.*)/)

    if match_data
      line.text = match_data[:text]
      line.quote_level = match_data[:indicators].length
    end
  end

  # @param line [Line]
  # @param previous_line [Line]
  # @return [Line]
  def merge_lines(line, previous_line)
    return line if previous_line.nil? || line.text.blank?
    return line if line.text == SIGNATURE_SEPARATOR || previous_line.text == SIGNATURE_SEPARATOR
    unless line.quote_level == previous_line.quote_level && previous_line.text.end_with?(" ")
      return line
    end

    previous_line.text = previous_line.text[0...-1] if @delete_flowed_space
    previous_line.text += line.text
    previous_line
  end

  # @param line [Line]
  # @param previous_line [Line]
  def classify_line_as_code!(line, previous_line)
    line.code_block = previous_line.code_block unless previous_line.nil? ||
      previous_line.valid_code_block?
    return unless line.text =~ /\A\s{0,3}```/

    if line.code_block.present?
      line.code_block.end_line = line
    else
      line.code_block = CodeBlock.new(line)
    end
  end

  # @param line [Line]
  # @return [string]
  def convert_text(line)
    text = line.text

    if line.valid_code_block?
      code_block = line.code_block
      return code_block.start_line == line || code_block.end_line == line ? text.lstrip : text
    end

    converted_text = replace_duplicate_links(text)
    converted_text = escape_special_characters(converted_text)
    converted_text = indent_with_non_breaking_spaces(converted_text)
    converted_text
  end

  URL_REGEX = URI.regexp(%w[http https ftp mailto])
  BEFORE = Regexp.escape(%Q|([<«"“'‘|)
  AFTER = Regexp.escape(%Q|)]>»"”'’|)

  def replace_duplicate_links(text)
    urls = Set.new
    text.scan(URL_REGEX) { urls << $& }

    urls.each do |url|
      escaped = Regexp.escape(url)
      text.gsub!(
        Regexp.new(%Q|#{escaped}\s*[#{BEFORE}]?#{escaped}[#{AFTER}]?|, Regexp::IGNORECASE),
        url,
      )
    end

    text
  end

  def indent_with_non_breaking_spaces(text)
    text.sub(/\A\s+/) do |s|
      # replace tabs with 2 spaces
      s.gsub!("\t", "  ")

      # replace indentation with non-breaking spaces
      s.length > 1 ? "&nbsp;" * s.length : s
    end
  end

  def escape_special_characters(text)
    urls = Set.new
    text.scan(URL_REGEX) { urls << $& }

    hoisted = urls.map { |url| [SecureRandom.hex, url] }.to_h

    hoisted.each { |h, url| text.gsub!(url, h) }

    text.gsub!(/[\\`*_{}\[\]()#+\-.!~]/) { |c| "\\#{c}" }
    text = CGI.escapeHTML(text)

    hoisted.each { |h, url| text.gsub!(h, url) }

    text
  end
end
