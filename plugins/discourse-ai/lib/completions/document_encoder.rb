# frozen_string_literal: true

module DiscourseAi
  module Completions
    class DocumentEncoder
      extend UploadEncoding

      TEXT_CONVERTERS = {
        "doc" => DocToText,
        "docx" => DocxToText,
        "xls" => XlsToText,
        "xlsx" => XlsxToText,
        "odt" => OdtToText,
        "ods" => OdsToText,
        "rtf" => RtfToText,
        "html" => HtmlToText,
      }.freeze

      PLAIN_TEXT_ATTACHMENT_TYPES = %w[csv md txt].freeze
      RAW_DOCUMENT_ATTACHMENT_TYPES = %w[pdf].freeze

      SUPPORTED_ATTACHMENT_TYPES =
        (TEXT_CONVERTERS.keys + PLAIN_TEXT_ATTACHMENT_TYPES + RAW_DOCUMENT_ATTACHMENT_TYPES).freeze

      UNKNOWN_ATTACHMENT_TYPE = "file"

      # order matters: the first fragment a mime type contains wins
      MIME_ATTACHMENT_TYPES = {
        "pdf" => "pdf",
        "wordprocessingml.document" => "docx",
        "application/msword" => "doc",
        "spreadsheetml.sheet" => "xlsx",
        "application/vnd.ms-excel" => "xls",
        "opendocument.text" => "odt",
        "opendocument.spreadsheet" => "ods",
        "csv" => "csv",
        "text/plain" => "txt",
        "rtf" => "rtf",
        "html" => "html",
        "markdown" => "md",
      }.freeze

      MAX_TEXT_FILE_BYTES = 1 * 1024 * 1024
      MAX_RAW_DOCUMENT_BYTES = 10 * 1024 * 1024

      class << self
        def encode(upload, mime_type, attachment_type, skips)
          path = fetch_path(upload)

          if path.blank?
            log_document_upload_skip(
              skips,
              upload,
              attachment_type,
              "file is not available in the store",
            )
            return
          end

          extract_text_payload(upload, path, attachment_type, skips) ||
            raw_document_payload(upload, path, mime_type, attachment_type, skips)
        end

        def attachment_type_for(extension, mime_type)
          ext = extension.to_s.delete_prefix(".").downcase
          ext = LlmModel::ATTACHMENT_TYPE_ALIASES.fetch(ext, ext)
          return ext if SUPPORTED_ATTACHMENT_TYPES.include?(ext)

          mime = mime_type.to_s.downcase
          MIME_ATTACHMENT_TYPES.find { |fragment, _| mime.include?(fragment) }&.last ||
            UNKNOWN_ATTACHMENT_TYPE
        end

        private

        def extract_text_payload(upload, path, attachment_type, skips)
          converter = TEXT_CONVERTERS[attachment_type]
          return if converter.nil? && PLAIN_TEXT_ATTACHMENT_TYPES.exclude?(attachment_type)

          raw = converter ? converter.convert(path) : read_utf8_text_file(path)
          text = normalize_extracted_text(raw)

          if text.blank?
            log_document_conversion_failure(
              skips,
              upload,
              attachment_type,
              "#{attachment_type.upcase} converter returned blank output",
            )
            return
          end

          text_document_payload(upload, path, text, converted_from: attachment_type)
        rescue StandardError => e
          log_document_conversion_failure(
            skips,
            upload,
            attachment_type,
            "#{e.class}: #{e.message}",
          )
          nil
        end

        def raw_document_payload(upload, path, mime_type, attachment_type, skips)
          if RAW_DOCUMENT_ATTACHMENT_TYPES.exclude?(attachment_type)
            log_document_upload_skip(
              skips,
              upload,
              attachment_type,
              "raw upload is not supported for this attachment type; it must be converted to text",
            )
            return
          end

          bytesize = File.size(path)
          if bytesize > MAX_RAW_DOCUMENT_BYTES
            log_document_upload_skip(
              skips,
              upload,
              attachment_type,
              "raw upload size #{ActiveSupport::NumberHelper.number_to_human_size(bytesize)} " \
                "exceeds the #{ActiveSupport::NumberHelper.number_to_human_size(MAX_RAW_DOCUMENT_BYTES)} limit",
            )
            return
          end

          {
            base64: Base64.strict_encode64(File.binread(path)),
            mime_type: mime_type,
            kind: :document,
            filename: upload.original_filename,
          }
        rescue SystemCallError => e
          log_document_upload_skip(skips, upload, attachment_type, "#{e.class}: #{e.message}")
          nil
        end

        def read_utf8_text_file(path)
          text = File.binread(path, MAX_TEXT_FILE_BYTES + 1) || +""
          truncated = text.bytesize > MAX_TEXT_FILE_BYTES
          text = text.byteslice(0, MAX_TEXT_FILE_BYTES) if truncated

          text.force_encoding("UTF-8")
          return text if !truncated

          text +
            "\n\n[Document text truncated after #{ActiveSupport::NumberHelper.number_to_human_size(MAX_TEXT_FILE_BYTES)}.]"
        end

        def normalize_extracted_text(output)
          Encodings.force_utf8(output.to_s).strip
        end

        def truncate_extracted_text(text)
          return text if text.length <= TextNormalization::DOCUMENT_TEXT_BUDGET

          text.first(TextNormalization::DOCUMENT_TEXT_BUDGET) +
            "\n\n[Document text truncated after #{TextNormalization::DOCUMENT_TEXT_BUDGET} characters.]"
        end

        def text_document_payload(upload, path, text, converted_from:)
          {
            kind: :document,
            filename: upload.original_filename,
            mime_type: "text/plain",
            text: document_text_preamble(upload, path) + truncate_extracted_text(text),
            converted_from: converted_from,
          }
        end

        def document_text_preamble(upload, path)
          filename = upload.original_filename.presence || "document"
          filesize = upload.filesize || File.size(path)
          "Uploaded document: #{filename} (#{ActiveSupport::NumberHelper.number_to_human_size(filesize)})\n\n"
        end

        def log_document_conversion_failure(skips, upload, extension, message)
          record_skip(skips, upload, message)

          Rails.logger.warn(
            "Discourse AI: Failed to convert .#{extension} upload to text " \
              "(upload_id=#{upload.id}, filename=#{upload.original_filename.inspect}): #{message}",
          )
        end

        def log_document_upload_skip(skips, upload, extension, message)
          record_skip(skips, upload, message)

          Rails.logger.warn(
            "Discourse AI: Skipping .#{extension} upload " \
              "(upload_id=#{upload.id}, filename=#{upload.original_filename.inspect}): #{message}",
          )
        end
      end
    end
  end
end
