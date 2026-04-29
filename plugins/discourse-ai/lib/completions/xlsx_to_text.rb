# frozen_string_literal: true

require "nokogiri"
require "pathname"
require "zip"

module DiscourseAi
  module Completions
    class XlsxToText
      MAX_ENTRY_XML_BYTES = 10 * 1024 * 1024
      MAX_TOTAL_XML_BYTES = 30 * 1024 * 1024
      READ_CHUNK_BYTES = 16 * 1024
      MAX_EXTRACTED_TEXT_CHARS = 100_001
      MAX_SHEETS = 50
      MAX_ROWS_PER_SHEET = 10_000
      MAX_COLUMNS = 200

      WORKBOOK_PATH = "xl/workbook.xml"
      WORKBOOK_RELS_PATH = "xl/_rels/workbook.xml.rels"
      SHARED_STRINGS_PATH = "xl/sharedStrings.xml"

      Sheet = Struct.new(:name, :path, keyword_init: true)

      class EntryTooLargeError < StandardError
      end

      def self.convert(path)
        new(path).convert
      end

      def initialize(path)
        @path = path
      end

      def convert
        remaining_bytes = MAX_TOTAL_XML_BYTES

        ::Zip::File.open(path) do |zip_file|
          shared_strings, remaining_bytes = shared_strings_for(zip_file, remaining_bytes)
          sheets, remaining_bytes = sheets_for(zip_file, remaining_bytes)

          sheet_texts = []
          extracted_chars = 0

          sheets
            .first(MAX_SHEETS)
            .each do |sheet|
              entry = zip_file.find_entry(sheet.path)
              next if entry.blank? || entry.directory?

              xml = read_xml_entry(entry, remaining_bytes)
              remaining_bytes -= xml.bytesize

              text = sheet_text(xml, shared_strings)
              next if text.blank?

              sheet_text = "Sheet: #{sheet.name}\n\n#{text}"
              sheet_texts << sheet_text
              extracted_chars += sheet_text.length + 2
              break if extracted_chars > MAX_EXTRACTED_TEXT_CHARS
            end

          normalize_document_text(sheet_texts.join("\n\n"))
        end
      end

      private

      attr_reader :path

      def shared_strings_for(zip_file, remaining_bytes)
        entry = zip_file.find_entry(SHARED_STRINGS_PATH)
        return [], remaining_bytes if entry.blank? || entry.directory?

        xml = read_xml_entry(entry, remaining_bytes)
        [parse_shared_strings(xml), remaining_bytes - xml.bytesize]
      end

      def parse_shared_strings(xml)
        doc = Nokogiri.XML(force_utf8(xml)) { |config| config.recover.nonet }
        doc.remove_namespaces!

        doc.xpath("//sst/si").map { |si| normalize_inline_text(string_item_text(si)) }
      end

      def sheets_for(zip_file, remaining_bytes)
        workbook_entry = zip_file.find_entry(WORKBOOK_PATH)
        if workbook_entry.blank? || workbook_entry.directory?
          return fallback_sheets(zip_file), remaining_bytes
        end

        rels = {}
        rels_entry = zip_file.find_entry(WORKBOOK_RELS_PATH)
        if rels_entry.present? && !rels_entry.directory?
          rels_xml = read_xml_entry(rels_entry, remaining_bytes)
          remaining_bytes -= rels_xml.bytesize
          rels = workbook_relationships(rels_xml)
        end

        workbook_xml = read_xml_entry(workbook_entry, remaining_bytes)
        remaining_bytes -= workbook_xml.bytesize

        sheets = parse_workbook_sheets(workbook_xml, rels)
        sheets = fallback_sheets(zip_file) if sheets.empty?
        [sheets, remaining_bytes]
      end

      def workbook_relationships(xml)
        doc = Nokogiri.XML(force_utf8(xml)) { |config| config.recover.nonet }
        doc.remove_namespaces!

        doc
          .xpath("//Relationship")
          .each_with_object({}) do |relationship, memo|
            id = relationship["Id"]
            target = relationship["Target"]
            memo[id] = workbook_target_path(target) if id.present? && target.present?
          end
      end

      def parse_workbook_sheets(xml, rels)
        doc = Nokogiri.XML(force_utf8(xml)) { |config| config.recover.nonet }
        doc.remove_namespaces!

        doc
          .xpath("//sheets/sheet")
          .filter_map do |sheet|
            rel_id = sheet["id"]
            sheet_path = rels[rel_id]
            next if sheet_path.blank?

            Sheet.new(
              name: sheet["name"].presence || File.basename(sheet_path, ".xml"),
              path: sheet_path,
            )
          end
      end

      def fallback_sheets(zip_file)
        zip_file
          .entries
          .select do |entry|
            entry.name.match?(%r{\Axl/worksheets/sheet\d+\.xml\z}) && !entry.directory?
          end
          .sort_by { |entry| entry.name.scan(/\d+/).last.to_i }
          .map
          .with_index { |entry, index| Sheet.new(name: "Sheet#{index + 1}", path: entry.name) }
      end

      def workbook_target_path(target)
        normalized_target = target.delete_prefix("/")
        normalized_target = File.join("xl", normalized_target) if !normalized_target.start_with?(
          "xl/",
        )
        Pathname.new(normalized_target).cleanpath.to_s
      end

      def read_xml_entry(entry, remaining_bytes)
        limit = [MAX_ENTRY_XML_BYTES, remaining_bytes].min
        raise EntryTooLargeError, "XLSX XML content is too large" if limit <= 0

        if entry.size && entry.size > limit
          raise EntryTooLargeError, "XLSX XML entry #{entry.name} is too large"
        end

        data = +""
        entry.get_input_stream do |stream|
          while (chunk = stream.read(READ_CHUNK_BYTES))
            data << chunk
            if data.bytesize > limit
              raise EntryTooLargeError, "XLSX XML entry #{entry.name} is too large"
            end
          end
        end

        data
      end

      def sheet_text(xml, shared_strings)
        doc = Nokogiri.XML(force_utf8(xml)) { |config| config.recover.nonet }
        doc.remove_namespaces!

        rows = doc.xpath("//sheetData/row")
        return if rows.blank?

        row_texts = []
        extracted_chars = 0

        rows
          .first(MAX_ROWS_PER_SHEET)
          .each do |row|
            text = row_text(row, shared_strings)
            next if text.blank?

            row_texts << text
            extracted_chars += text.length + 1
            break if extracted_chars > MAX_EXTRACTED_TEXT_CHARS
          end

        row_texts.join("\n")
      end

      def row_text(row, shared_strings)
        cells = row.xpath("./c")
        return if cells.blank?

        values = []
        next_column_index = 0

        cells.each do |cell|
          column_index = column_index_for(cell["r"]) || next_column_index
          next_column_index = column_index + 1
          next if column_index >= MAX_COLUMNS

          values.concat([""] * (column_index - values.length)) if column_index > values.length
          values[column_index] = cell_text(cell, shared_strings)
        end

        values.pop while values.last.blank?
        values.join("\t")
      end

      def cell_text(cell, shared_strings)
        type = cell["t"]
        value = cell.at_xpath("./v")&.text

        text =
          case type
          when "s"
            shared_strings[value.to_i] if value.present?
          when "inlineStr"
            string_item_text(cell.at_xpath("./is"))
          when "b"
            value.to_s == "1" ? "TRUE" : "FALSE" if value.present?
          when "str", "e"
            value
          else
            value.presence || formula_text(cell)
          end

        normalize_inline_text(text)
      end

      def formula_text(cell)
        formula = cell.at_xpath("./f")&.text
        formula.present? ? "=#{formula}" : nil
      end

      def string_item_text(node)
        return if node.blank?

        direct_text = node.xpath("./t").map(&:text).join
        return direct_text if direct_text.present?

        node.xpath("./r/t").map(&:text).join
      end

      def column_index_for(reference)
        column_name = reference.to_s[/\A[A-Z]+/i]
        return if column_name.blank?

        column_name.upcase.each_byte.reduce(0) { |index, char| (index * 26) + char - "A".ord + 1 } -
          1
      end

      def normalize_inline_text(text)
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
