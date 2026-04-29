# frozen_string_literal: true

module DiscourseAi
  module Completions
    class UploadEncoder
      def self.encode(
        upload_ids:,
        max_pixels:,
        allowed_kinds: [:image],
        allowed_attachment_types: nil
      )
        uploads = []
        allowed_attachment_types = normalize_attachment_types(allowed_attachment_types)
        upload_ids.each do |upload_id|
          upload = Upload.find(upload_id)
          next if upload.blank?

          extension = upload.extension&.downcase
          kind = image_extension?(extension) ? :image : :document

          next if allowed_kinds.exclude?(kind)

          if kind == :document
            mime_type =
              MiniMime.lookup_by_filename(upload.original_filename)&.content_type ||
                "application/octet-stream"

            attachment_type = attachment_type_for(upload.extension, mime_type)
            next if disallowed_attachment?(allowed_attachment_types, attachment_type)

            payload = encode_document(upload, mime_type, attachment_type)
            uploads << payload if payload
            next
          end

          next if upload.width.to_i == 0 || upload.height.to_i == 0

          desired_extension = upload.extension
          desired_extension = "png" if upload.extension == "gif"
          desired_extension = "png" if upload.extension == "webp"
          desired_extension = "jpeg" if upload.extension == "jpg"

          # this keeps it very simple format wise given everyone supports png and jpg
          next if !%w[jpeg png].include?(desired_extension)

          payload = encode_image(upload, desired_extension, max_pixels)
          uploads << payload if payload
        end
        uploads
      end

      MAX_EXTRACTED_DOCUMENT_TEXT_CHARS = 100_000
      MAX_TEXT_FILE_BYTES = 1 * 1024 * 1024
      MAX_RAW_DOCUMENT_BYTES = 10 * 1024 * 1024
      RAW_DOCUMENT_ATTACHMENT_TYPES = %w[pdf]

      def self.attachment_type_for(extension, mime_type)
        ext = extension.to_s.delete_prefix(".").downcase
        mime = mime_type.to_s.downcase

        return "pdf" if ext == "pdf" || mime.include?("pdf")
        return "docx" if ext == "docx" || mime.include?("wordprocessingml.document")
        return "doc" if ext == "doc" || mime == "application/msword"
        return "xlsx" if ext == "xlsx" || mime.include?("spreadsheetml.sheet")
        return "xls" if ext == "xls" || mime == "application/vnd.ms-excel"
        return "csv" if ext == "csv" || mime.include?("text/csv") || mime.include?("csv")
        return "txt" if ext == "txt" || mime.include?("text/plain")
        return "rtf" if ext == "rtf" || mime.include?("rtf")
        return "html" if %w[html htm].include?(ext) || mime.include?("html")
        return "md" if %w[md markdown].include?(ext) || mime.include?("markdown")

        "file"
      end

      class << self
        private

        def normalize_attachment_types(types)
          return nil if types.nil?

          LlmModel.normalize_attachment_types(types)
        end

        def disallowed_attachment?(allowed_types, attachment_type)
          !allowed_types.nil? && !allowed_types.include?(attachment_type)
        end

        def image_extension?(ext)
          %w[jpg jpeg png gif webp].include?(ext)
        end

        def encode_document(upload, mime_type, attachment_type)
          path = fetch_path(upload)
          return if path.blank?

          if attachment_type == "doc"
            text_payload = doc_to_text_payload(upload, path)
            return text_payload if text_payload
          elsif attachment_type == "docx"
            text_payload = docx_to_text_payload(upload, path)
            return text_payload if text_payload
          elsif attachment_type == "xls"
            text_payload = xls_to_text_payload(upload, path)
            return text_payload if text_payload
          elsif attachment_type == "xlsx"
            text_payload = xlsx_to_text_payload(upload, path)
            return text_payload if text_payload
          elsif attachment_type == "rtf"
            text_payload = rtf_to_text_payload(upload, path)
            return text_payload if text_payload
          elsif %w[csv md txt].include?(attachment_type)
            text_payload = text_file_payload(upload, path, attachment_type)
            return text_payload if text_payload
          end

          raw_document_payload(upload, path, mime_type, attachment_type)
        end

        def raw_document_payload(upload, path, mime_type, attachment_type)
          if RAW_DOCUMENT_ATTACHMENT_TYPES.exclude?(attachment_type)
            log_document_upload_skip(
              upload,
              attachment_type,
              "raw upload is not supported for this attachment type; it must be converted to text",
            )
            return
          end

          bytesize = File.size(path)
          if bytesize > MAX_RAW_DOCUMENT_BYTES
            log_document_upload_skip(
              upload,
              attachment_type,
              "raw upload size #{human_filesize(bytesize)} exceeds the #{human_filesize(MAX_RAW_DOCUMENT_BYTES)} limit",
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
          log_document_upload_skip(upload, attachment_type, "#{e.class}: #{e.message}")
          nil
        end

        def doc_to_text_payload(upload, path)
          text = normalize_extracted_text(DiscourseAi::Completions::DocToText.convert(path))

          if text.blank?
            log_document_conversion_failure(upload, "doc", "DOC converter returned blank output")
            return
          end

          text_document_payload(upload, path, text, converted_from: "doc")
        rescue StandardError => e
          log_document_conversion_failure(upload, "doc", "#{e.class}: #{e.message}")
          nil
        end

        def docx_to_text_payload(upload, path)
          text = normalize_extracted_text(DiscourseAi::Completions::DocxToText.convert(path))

          if text.blank?
            log_document_conversion_failure(upload, "docx", "DOCX converter returned blank output")
            return
          end

          text_document_payload(upload, path, text, converted_from: "docx")
        rescue StandardError => e
          log_document_conversion_failure(upload, "docx", "#{e.class}: #{e.message}")
          nil
        end

        def xls_to_text_payload(upload, path)
          text = normalize_extracted_text(DiscourseAi::Completions::XlsToText.convert(path))

          if text.blank?
            log_document_conversion_failure(upload, "xls", "XLS converter returned blank output")
            return
          end

          text_document_payload(upload, path, text, converted_from: "xls")
        rescue StandardError => e
          log_document_conversion_failure(upload, "xls", "#{e.class}: #{e.message}")
          nil
        end

        def xlsx_to_text_payload(upload, path)
          text = normalize_extracted_text(DiscourseAi::Completions::XlsxToText.convert(path))

          if text.blank?
            log_document_conversion_failure(upload, "xlsx", "XLSX converter returned blank output")
            return
          end

          text_document_payload(upload, path, text, converted_from: "xlsx")
        rescue StandardError => e
          log_document_conversion_failure(upload, "xlsx", "#{e.class}: #{e.message}")
          nil
        end

        def text_file_payload(upload, path, attachment_type)
          text = normalize_extracted_text(read_utf8_text_file(path))

          if text.blank?
            log_document_conversion_failure(upload, attachment_type, "text file was blank")
            return
          end

          text_document_payload(upload, path, text, converted_from: attachment_type)
        rescue SystemCallError => e
          log_document_conversion_failure(upload, attachment_type, "#{e.class}: #{e.message}")
          nil
        end

        def rtf_to_text_payload(upload, path)
          text = normalize_extracted_text(DiscourseAi::Completions::RtfToText.convert(path))

          if text.blank?
            log_document_conversion_failure(upload, "rtf", "RTF converter returned blank output")
            return
          end

          text_document_payload(upload, path, text, converted_from: "rtf")
        rescue StandardError => e
          log_document_conversion_failure(upload, "rtf", "#{e.class}: #{e.message}")
          nil
        end

        def read_utf8_text_file(path)
          text = +""
          truncated = false

          File.open(path, "rb") do |file|
            text = file.read(MAX_TEXT_FILE_BYTES + 1).to_s
            if text.bytesize > MAX_TEXT_FILE_BYTES
              text = text.byteslice(0, MAX_TEXT_FILE_BYTES)
              truncated = true
            end
          end

          text = text.delete_prefix("\xEF\xBB\xBF".b)
          text.force_encoding("UTF-8")
          text = text.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

          if truncated
            text << "\n\n[Document text truncated after #{human_filesize(MAX_TEXT_FILE_BYTES)}.]"
          end

          text
        end

        def normalize_extracted_text(output)
          output.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
        end

        def truncate_extracted_text(text)
          return text if text.length <= MAX_EXTRACTED_DOCUMENT_TEXT_CHARS

          text.first(MAX_EXTRACTED_DOCUMENT_TEXT_CHARS) +
            "\n\n[Document text truncated after #{MAX_EXTRACTED_DOCUMENT_TEXT_CHARS} characters.]"
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
          "Uploaded document: #{filename} (#{human_filesize(filesize)})\n\n"
        end

        def human_filesize(bytes)
          bytes = bytes.to_i
          units = %w[Bytes KB MB GB TB]
          size = bytes.to_f
          unit = units.shift

          while size >= 1024 && units.any?
            size /= 1024.0
            unit = units.shift
          end

          return "#{bytes} #{bytes == 1 ? "Byte" : "Bytes"}" if unit == "Bytes"

          formatted_size = size >= 10 ? size.round.to_s : format("%.1f", size).sub(/\.0\z/, "")
          "#{formatted_size} #{unit}"
        end

        def log_document_conversion_failure(upload, extension, message)
          Rails.logger.warn(
            "Discourse AI: Failed to convert .#{extension} upload to text " \
              "(upload_id=#{upload.id}, filename=#{upload.original_filename.inspect}): #{message}",
          )
        end

        def log_document_upload_skip(upload, extension, message)
          Rails.logger.warn(
            "Discourse AI: Skipping .#{extension} upload " \
              "(upload_id=#{upload.id}, filename=#{upload.original_filename.inspect}): #{message}",
          )
        end

        def encode_image(upload, desired_extension, max_pixels)
          original_pixels = upload.width * upload.height

          image = upload

          if original_pixels > max_pixels
            ratio = max_pixels.to_f / original_pixels

            new_width = (ratio * upload.width).to_i
            new_height = (ratio * upload.height).to_i

            image = upload.get_optimized_image(new_width, new_height, format: desired_extension)
          elsif upload.extension != desired_extension
            image =
              upload.get_optimized_image(upload.width, upload.height, format: desired_extension)
          end

          return if !image

          mime_type = MiniMime.lookup_by_filename("test.#{desired_extension}").content_type

          path = fetch_path(image)
          return if path.blank?

          encoded = Base64.strict_encode64(File.binread(path))

          {
            base64: encoded,
            mime_type: mime_type,
            kind: :image,
            filename: upload.original_filename,
          }
        end

        def fetch_path(upload)
          path = Discourse.store.path_for(upload)
          path = Discourse.store.download(upload) if path.blank?

          return if path.blank?
          return unless File.exist?(path)

          path
        end
      end
    end
  end
end
