# frozen_string_literal: true

require "nokogiri"
require "compression/safe_zip_reader"

module DiscourseAi
  module Completions
    class DocxToText
      MAX_ENTRY_XML_BYTES = 10 * 1024 * 1024
      MAX_TOTAL_XML_BYTES = 30 * 1024 * 1024
      MAX_ZIP_ENTRIES = 1_000
      MAX_EXTRACTED_TEXT_CHARS = 100_001
      MAX_PARAGRAPHS = 20_000

      SUPPORTED_PARTS = %w[word/document.xml word/footnotes.xml word/endnotes.xml word/comments.xml]
      IMAGE_ALT_ATTRIBUTES = %w[descr title alt]
      IMAGE_ALT_NODES = %w[docPr cNvPr shape imagedata]

      class EntryTooLargeError < StandardError
      end

      class Numbering
        Level = Struct.new(:num_format, :level_text, :start, keyword_init: true)

        BULLET_FORMAT = "bullet"
        DEFAULT_START = 1
        DEFAULT_NUM_FORMAT = "decimal"
        ROMAN_NUMERALS = {
          1000 => "M",
          900 => "CM",
          500 => "D",
          400 => "CD",
          100 => "C",
          90 => "XC",
          50 => "L",
          40 => "XL",
          10 => "X",
          9 => "IX",
          5 => "V",
          4 => "IV",
          1 => "I",
        }

        def self.from_xml(xml)
          new.tap { |numbering| numbering.parse(xml) }
        end

        def initialize
          @abstract_levels = Hash.new { |hash, key| hash[key] = {} }
          @num_abstract_ids = {}
          @num_level_overrides = Hash.new { |hash, key| hash[key] = {} }
          @counters = Hash.new { |hash, key| hash[key] = {} }
        end

        def parse(xml)
          doc = Nokogiri.XML(force_utf8(xml)) { |config| config.recover.nonet }
          doc.remove_namespaces!

          parse_abstract_levels(doc)
          parse_numbering_instances(doc)
        end

        def prefix_for(paragraph)
          num_pr = paragraph.at_xpath("./pPr/numPr")
          return if num_pr.blank?

          num_id = num_pr.at_xpath("./numId")&.[]("val")
          return if num_id.blank?

          ilvl = integer_value(num_pr.at_xpath("./ilvl")&.[]("val"))
          level = level_for(num_id, ilvl)
          return if level.blank?

          indent = "  " * ilvl
          if bullet?(level)
            reset_deeper_counters(num_id, ilvl)
            "#{indent}#{bullet_for(level)} "
          else
            increment_counter(num_id, ilvl, level)
            "#{indent}#{render_level_text(num_id, ilvl, level)} "
          end
        end

        private

        attr_reader :abstract_levels, :num_abstract_ids, :num_level_overrides, :counters

        def parse_abstract_levels(doc)
          doc
            .xpath("//abstractNum")
            .each do |abstract_num|
              abstract_id = abstract_num["abstractNumId"]
              next if abstract_id.blank?

              abstract_num
                .xpath("./lvl")
                .each do |level_node|
                  ilvl = integer_value(level_node["ilvl"])
                  abstract_levels[abstract_id][ilvl] = level_from_node(level_node)
                end
            end
        end

        def parse_numbering_instances(doc)
          doc
            .xpath("//num")
            .each do |num|
              num_id = num["numId"]
              next if num_id.blank?

              abstract_id = num.at_xpath("./abstractNumId")&.[]("val")
              num_abstract_ids[num_id] = abstract_id if abstract_id.present?

              num
                .xpath("./lvlOverride")
                .each do |override_node|
                  ilvl = integer_value(override_node["ilvl"])
                  num_level_overrides[num_id][ilvl] = override_level(num_id, ilvl, override_node)
                end
            end
        end

        def override_level(num_id, ilvl, override_node)
          start_override = integer_value(override_node.at_xpath("./startOverride")&.[]("val"), nil)
          override_level_node = override_node.at_xpath("./lvl")
          level =
            (
              if override_level_node
                level_from_node(override_level_node)
              else
                level_for(num_id, ilvl)&.dup
              end
            )
          level ||=
            Level.new(
              num_format: DEFAULT_NUM_FORMAT,
              level_text: "%#{ilvl + 1}.",
              start: DEFAULT_START,
            )
          level.start = start_override if start_override.present?
          level
        end

        def level_from_node(level_node)
          Level.new(
            num_format: level_node.at_xpath("./numFmt")&.[]("val") || DEFAULT_NUM_FORMAT,
            level_text: level_node.at_xpath("./lvlText")&.[]("val"),
            start: integer_value(level_node.at_xpath("./start")&.[]("val"), DEFAULT_START),
          )
        end

        def level_for(num_id, ilvl)
          num_level_overrides.dig(num_id, ilvl) ||
            abstract_levels.dig(num_abstract_ids[num_id], ilvl)
        end

        def bullet?(level)
          level.num_format == BULLET_FORMAT
        end

        def bullet_for(level)
          bullet = level.level_text.to_s.strip
          if bullet.blank? || bullet.match?(/%\d/) || bullet.match?(/\A[\u{F000}-\u{F8FF}]\z/)
            return "•"
          end

          bullet
        end

        def increment_counter(num_id, ilvl, level)
          list_counters = counters[num_id]

          (0...ilvl).each do |parent_ilvl|
            parent_level = level_for(num_id, parent_ilvl)
            next if parent_level.blank? || bullet?(parent_level)

            list_counters[parent_ilvl] ||= parent_level.start || DEFAULT_START
          end

          list_counters[ilvl] = list_counters.key?(ilvl) ? list_counters[ilvl] + 1 : level.start
          reset_deeper_counters(num_id, ilvl)
        end

        def reset_deeper_counters(num_id, ilvl)
          counters[num_id].keys.each do |counter_ilvl|
            counters[num_id].delete(counter_ilvl) if counter_ilvl > ilvl
          end
        end

        def render_level_text(num_id, ilvl, level)
          level_text = level.level_text.presence || "%#{ilvl + 1}."

          level_text.gsub(/%(\d+)/) do
            referenced_ilvl = Regexp.last_match(1).to_i - 1
            referenced_level = level_for(num_id, referenced_ilvl)
            value = counters[num_id][referenced_ilvl] || referenced_level&.start || DEFAULT_START
            format_counter(value, referenced_level&.num_format || DEFAULT_NUM_FORMAT)
          end
        end

        def format_counter(value, num_format)
          case num_format
          when "decimal"
            value.to_s
          when "decimalZero"
            format("%02d", value)
          when "lowerLetter"
            alphabetic_counter(value)
          when "upperLetter"
            alphabetic_counter(value).upcase
          when "lowerRoman"
            roman_counter(value).downcase
          when "upperRoman"
            roman_counter(value)
          when "ordinal"
            ordinal_counter(value)
          else
            value.to_s
          end
        end

        def alphabetic_counter(value)
          value = value.to_i
          return value.to_s if value < 1

          text = +""
          while value.positive?
            value -= 1
            text.prepend(("a".ord + (value % 26)).chr)
            value /= 26
          end
          text
        end

        def roman_counter(value)
          value = value.to_i
          return value.to_s if value < 1

          text = +""
          ROMAN_NUMERALS.each do |number, numeral|
            while value >= number
              text << numeral
              value -= number
            end
          end
          text
        end

        def ordinal_counter(value)
          suffix =
            if (11..13).include?(value % 100)
              "th"
            else
              case value % 10
              when 1
                "st"
              when 2
                "nd"
              when 3
                "rd"
              else
                "th"
              end
            end

          "#{value}#{suffix}"
        end

        def integer_value(value, default = 0)
          value.present? ? value.to_i : default
        end

        def force_utf8(text)
          text.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        end
      end

      def self.convert(path)
        new(path).convert
      end

      def initialize(path)
        @path = path
      end

      def convert
        part_texts = []
        extracted_chars = 0

        Compression::SafeZipReader.open(
          path,
          max_entries: MAX_ZIP_ENTRIES,
          max_total_bytes: MAX_TOTAL_XML_BYTES,
        ) do |zip_file|
          numbering = numbering_for(zip_file)

          text_entries(zip_file).each do |entry|
            xml = read_xml_entry(zip_file, entry)

            text = extract_text_from_xml(xml, numbering)
            next if text.blank?

            part_texts << text
            extracted_chars += text.length + 2
            break if extracted_chars > MAX_EXTRACTED_TEXT_CHARS
          end
        end

        normalize_document_text(part_texts.join("\n\n"))
      end

      private

      attr_reader :path

      def numbering_for(zip_file)
        entry = zip_file.find_entry("word/numbering.xml")
        return Numbering.new if entry.blank? || entry.directory?

        Numbering.from_xml(read_xml_entry(zip_file, entry))
      end

      def text_entries(zip_file)
        zip_file
          .entries
          .select { |entry| text_part_name?(entry.name) && !entry.directory? }
          .sort_by { |entry| part_sort_key(entry.name) }
      end

      def text_part_name?(name)
        SUPPORTED_PARTS.include?(name) || name.match?(%r{\Aword/(?:header|footer)\d+\.xml\z})
      end

      def part_sort_key(name)
        case name
        when "word/document.xml"
          [0, 0]
        when %r{\Aword/header(\d+)\.xml\z}
          [1, Regexp.last_match(1).to_i]
        when %r{\Aword/footer(\d+)\.xml\z}
          [2, Regexp.last_match(1).to_i]
        when "word/footnotes.xml"
          [3, 0]
        when "word/endnotes.xml"
          [4, 0]
        when "word/comments.xml"
          [5, 0]
        else
          [99, name]
        end
      end

      def read_xml_entry(zip_file, entry)
        zip_file.read_entry(entry, max_bytes: MAX_ENTRY_XML_BYTES)
      rescue Compression::SafeZipReader::EntryTooLargeError => e
        raise EntryTooLargeError, e.message
      end

      def extract_text_from_xml(xml, numbering)
        doc = Nokogiri.XML(force_utf8(xml)) { |config| config.recover.nonet }
        doc.remove_namespaces!

        paragraphs = doc.xpath("//p")
        nodes = paragraphs.presence || [doc.root].compact

        text_parts = []
        extracted_chars = 0

        nodes
          .first(MAX_PARAGRAPHS)
          .each do |node|
            text = normalize_paragraph_text(text_for_node(node))
            next if text.blank?

            text = "#{numbering.prefix_for(node)}#{text}"
            text_parts << text
            extracted_chars += text.length + 1
            break if extracted_chars > MAX_EXTRACTED_TEXT_CHARS
          end

        text_parts.join("\n")
      end

      def text_for_node(node)
        text = +""

        node.traverse do |child|
          next if !child.element?

          case child.name
          when "t"
            text << child.text
          when "tab"
            text << "\t"
          when "br", "cr"
            text << "\n"
          when "drawing", "pict"
            alt_text = image_alt_text(child)
            text << "[Image: #{alt_text}]" if alt_text.present?
          end
        end

        text
      end

      def image_alt_text(node)
        node
          .xpath(".//*")
          .select { |child| IMAGE_ALT_NODES.include?(child.name) }
          .flat_map { |child| IMAGE_ALT_ATTRIBUTES.filter_map { |attribute| child[attribute] } }
          .map { |text| normalize_inline_text(text) }
          .reject(&:blank?)
          .uniq
          .join(" - ")
      end

      def normalize_inline_text(text)
        force_utf8(text).gsub("\u00A0", " ").gsub(/\s+/, " ").strip
      end

      def normalize_paragraph_text(text)
        force_utf8(text)
          .gsub("\u00A0", " ")
          .gsub(/\r\n?/, "\n")
          .gsub(/[ \t]+\n/, "\n")
          .gsub(/\n[ \t]+/, "\n")
          .rstrip
      end

      def normalize_document_text(text)
        force_utf8(text)
          .gsub("\u00A0", " ")
          .gsub(/\r\n?/, "\n")
          .gsub(/[ \t]+\n/, "\n")
          .gsub(/\n{3,}/, "\n\n")
          .strip
      end

      def force_utf8(text)
        text.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      end
    end
  end
end
