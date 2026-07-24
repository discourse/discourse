# frozen_string_literal: true

require "nokogiri"
require "compression/safe_zip_reader"

module DiscourseAi
  module Completions
    class OdsToText
      MAX_ENTRY_XML_BYTES = 10 * 1024 * 1024
      MAX_TOTAL_XML_BYTES = 30 * 1024 * 1024
      MAX_ZIP_ENTRIES = 1_000
      MAX_EXTRACTED_TEXT_CHARS = 100_001
      MAX_SHEETS = 50
      MAX_ROWS_PER_SHEET = 10_000
      MAX_COLUMNS = 200

      CONTENT_PATH = "content.xml"

      class EntryTooLargeError < StandardError
      end

      def self.convert(path)
        new(path).convert
      end

      def initialize(path)
        @path = path
      end

      def convert
        Compression::SafeZipReader.open(
          path,
          max_entries: MAX_ZIP_ENTRIES,
          max_total_bytes: MAX_TOTAL_XML_BYTES,
        ) do |zip_file|
          xml = read_xml_entry(zip_file, CONTENT_PATH)
          return "" if xml.blank?

          normalize_document_text(extract_sheets(xml))
        end
      end

      private

      attr_reader :path

      def read_xml_entry(zip_file, name)
        entry = zip_file.find_entry(name)
        return if entry.blank? || entry.directory?

        zip_file.read_entry(entry, max_bytes: MAX_ENTRY_XML_BYTES)
      rescue Compression::SafeZipReader::EntryTooLargeError => e
        raise EntryTooLargeError, e.message
      end

      def extract_sheets(xml)
        doc = Nokogiri.XML(force_utf8(xml)) { |config| config.recover.nonet }
        doc.remove_namespaces!

        sheets = doc.xpath("//body/spreadsheet/table")
        return "" if sheets.blank?

        sheet_texts = []
        extracted_chars = 0

        sheets
          .first(MAX_SHEETS)
          .each_with_index do |sheet, index|
            name = sheet["name"].presence || "Sheet#{index + 1}"
            rows_text = sheet_rows(sheet)
            next if rows_text.blank?

            block = "Sheet: #{name}\n\n#{rows_text}"
            sheet_texts << block
            extracted_chars += block.length + 2
            break if extracted_chars > MAX_EXTRACTED_TEXT_CHARS
          end

        sheet_texts.join("\n\n")
      end

      def sheet_rows(sheet)
        rows = sheet.xpath("./table-row")
        return if rows.blank?

        row_texts = []
        extracted_chars = 0

        rows
          .first(MAX_ROWS_PER_SHEET)
          .each do |row|
            line = row_line(row)
            next if line.blank?

            row_texts << line
            extracted_chars += line.length + 1
            break if extracted_chars > MAX_EXTRACTED_TEXT_CHARS
          end

        row_texts.join("\n")
      end

      def row_line(row)
        values = []

        row
          .xpath("./table-cell | ./covered-table-cell")
          .each do |cell|
            break if values.length >= MAX_COLUMNS

            repeat = cell["number-columns-repeated"].to_i
            repeat = 1 if repeat < 1

            text = cell.name == "covered-table-cell" ? "" : cell_text(cell)

            if text.blank?
              values << ""
            else
              slots = [repeat, MAX_COLUMNS - values.length].min
              slots.times { values << text }
            end
          end

        values.pop while values.last&.blank? && values.any?
        values.join("\t")
      end

      def cell_text(cell)
        paragraphs = cell.xpath("./p")
        return normalize_inline(paragraphs.map { |p| inline_text(p) }.join("\n")) if paragraphs.any?

        case cell["value-type"]
        when "boolean"
          cell["boolean-value"].to_s == "true" ? "TRUE" : "FALSE"
        when "date"
          normalize_inline(cell["date-value"])
        when "time"
          normalize_inline(cell["time-value"])
        else
          normalize_inline(cell["value"])
        end
      end

      def inline_text(node)
        out = +""
        collect_inline(node, out)
        out
      end

      def collect_inline(node, out)
        node.children.each do |child|
          if child.text?
            out << child.content
          elsif child.element?
            case child.name
            when "tab"
              out << "\t"
            when "s"
              count = child["c"].to_i
              count = 1 if count < 1
              out << (" " * count)
            when "line-break"
              out << "\n"
            else
              collect_inline(child, out)
            end
          end
        end
      end

      def normalize_inline(text)
        force_utf8(text).gsub("\u00A0", " ").gsub(/[ \t\r\n]+/, " ").strip
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
