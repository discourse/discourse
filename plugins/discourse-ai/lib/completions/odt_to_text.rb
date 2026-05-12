# frozen_string_literal: true

require "nokogiri"
require "compression/safe_zip_reader"

module DiscourseAi
  module Completions
    class OdtToText
      MAX_ENTRY_XML_BYTES = 10 * 1024 * 1024
      MAX_TOTAL_XML_BYTES = 30 * 1024 * 1024
      MAX_ZIP_ENTRIES = 1_000
      MAX_EXTRACTED_TEXT_CHARS = 100_001
      MAX_PARAGRAPHS = 20_000
      MAX_LIST_DEPTH = 20

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

          normalize_document_text(extract_text(xml))
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

      def extract_text(xml)
        doc = Nokogiri.XML(force_utf8(xml)) { |config| config.recover.nonet }
        doc.remove_namespaces!

        body = doc.at_xpath("//body/text") || doc.at_xpath("//body") || doc.root
        return "" if body.nil?

        @text_parts = []
        @extracted_chars = 0
        @paragraph_count = 0

        walk(body, list_depth: 0)

        @text_parts.join("\n")
      end

      def walk(node, list_depth:)
        node.element_children.each do |child|
          break if hit_limits?

          case child.name
          when "p", "h"
            push_paragraph(child)
          when "list"
            walk_list(child, depth: list_depth) if list_depth < MAX_LIST_DEPTH
          when "table"
            walk_table(child)
          when "frame", "section", "text-box"
            walk(child, list_depth: list_depth)
          else
            walk(child, list_depth: list_depth) if child.element_children.any?
          end
        end
      end

      def walk_list(list_node, depth:)
        list_node
          .xpath("./list-item")
          .each do |item|
            break if hit_limits?

            item.element_children.each do |child|
              case child.name
              when "p", "h"
                push_paragraph(child, prefix: "#{"  " * depth}- ")
              when "list"
                walk_list(child, depth: depth + 1) if depth + 1 < MAX_LIST_DEPTH
              else
                walk(child, list_depth: depth + 1) if child.element_children.any?
              end
            end
          end
      end

      def walk_table(table_node)
        table_node
          .xpath(".//table-row")
          .each do |row|
            break if hit_limits?

            cells = row.xpath("./table-cell").map { |cell| normalize_inline(inline_text(cell)) }
            cells.pop while cells.last&.blank? && cells.any?
            next if cells.empty?

            push_line(cells.join("\t"))
          end
      end

      def push_paragraph(node, prefix: "")
        text = normalize_paragraph(inline_text(node))
        return if text.blank?

        push_line("#{prefix}#{text}")
      end

      def push_line(line)
        @text_parts << line
        @extracted_chars += line.length + 1
        @paragraph_count += 1
      end

      def hit_limits?
        @paragraph_count >= MAX_PARAGRAPHS || @extracted_chars > MAX_EXTRACTED_TEXT_CHARS
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

      def normalize_paragraph(text)
        force_utf8(text)
          .gsub("\u00A0", " ")
          .gsub(/\r\n?/, "\n")
          .gsub(/[ \t]+\n/, "\n")
          .gsub(/\n[ \t]+/, "\n")
          .rstrip
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
