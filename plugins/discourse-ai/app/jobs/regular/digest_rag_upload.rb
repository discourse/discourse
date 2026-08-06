# frozen_string_literal: true

module Jobs
  class DigestRagUpload < ::Jobs::Base
    CHUNK_SIZE = 1024
    CHUNK_OVERLAP = 64
    MAX_FRAGMENTS = 100_000
    UTF8_TEXT_EXTENSIONS = %w[md txt].freeze

    # TODO(roman): Add a way to automatically recover from errors, resulting in unindexed uploads.
    def execute(args)
      return unless upload = Upload.find_by(id: args[:upload_id])
      return unless target_type = args[:target_type]
      return unless target_id = args[:target_id]
      return unless target = target_type.constantize.find_by(id: target_id)

      vector_rep = DiscourseAi::Embeddings::Vector.instance

      tokenizer = vector_rep.tokenizer
      chunk_tokens = target.rag_chunk_tokens
      overlap_tokens = target.rag_chunk_overlap_tokens

      fragment_ids = RagDocumentFragment.where(target:, upload:).pluck(:id)

      # Check if this is the first time we process this upload.
      if fragment_ids.empty?
        document = get_uploaded_file(upload:, target:)
        return if document.nil?

        RagDocumentFragment.publish_status(upload, { total: 0, indexed: 0, left: 0 })

        fragment_ids = []
        idx = 0

        ActiveRecord::Base.transaction do
          chunk_document(
            file: document,
            extension: upload.extension,
            tokenizer:,
            chunk_tokens:,
            overlap_tokens:,
          ) do |chunk, metadata|
            fragment_ids << RagDocumentFragment.create!(
              target:,
              fragment: chunk,
              fragment_number: idx + 1,
              upload:,
              metadata:,
            ).id

            idx += 1

            if idx > MAX_FRAGMENTS
              Rails.logger.warn("Upload #{upload.id} has too many fragments, truncating.")
              break
            end
          end
        end
      end

      fragment_ids.each_slice(50) do |slice|
        Jobs.enqueue(:generate_rag_embeddings, fragment_ids: slice)
      end
    ensure
      @file&.close
    end

    private

    def chunk_document(file:, extension:, tokenizer:, chunk_tokens:, overlap_tokens:)
      buffer = +""
      current_metadata = nil
      done = false
      overlap = ""

      # generally this will be plenty
      read_size = chunk_tokens * 10
      document_chunks = each_document_chunk(file:, extension:, read_size:)

      while buffer.present? || !done
        while buffer.length < read_size && !done
          begin
            buffer << document_chunks.next
          rescue StopIteration
            done = true
          end
        end

        metadata_regex = /\[\[metadata (.*?)\]\]/m

        before_metadata, new_metadata, after_metadata = buffer.split(metadata_regex)
        to_chunk = nil

        if before_metadata.present?
          to_chunk = before_metadata
        elsif after_metadata.present?
          current_metadata = new_metadata
          to_chunk = after_metadata
          buffer = buffer.split(metadata_regex, 2).last
          overlap = ""
        else
          current_metadata = new_metadata
          buffer = buffer.split(metadata_regex, 2).last
          overlap = ""
          next
        end

        chunk, split_char = first_chunk(to_chunk, tokenizer: tokenizer, chunk_tokens: chunk_tokens)
        buffer = buffer[chunk.length..-1]

        processed_chunk = overlap + chunk

        processed_chunk.strip!
        processed_chunk.gsub!(/\n[\n]+/, "\n\n")

        yield processed_chunk, current_metadata

        current_chunk_tokens = tokenizer.encode(chunk)
        overlap_token_ids = current_chunk_tokens[-overlap_tokens..-1] || current_chunk_tokens

        overlap = ""

        while overlap_token_ids.present?
          begin
            padding = split_char
            padding = " " if padding.empty?
            overlap = tokenizer.decode(overlap_token_ids) + padding
            break if overlap.encoding == Encoding::UTF_8
          rescue StandardError
            # it is possible that we truncated mid char
          end
          overlap_token_ids.shift
        end

        # remove first word it is probably truncated
        overlap = overlap.split(/\s/, 2).last.to_s.lstrip
      end
    end

    def each_document_chunk(file:, extension:, read_size:)
      return enum_for(__method__, file:, extension:, read_size:) if !block_given?

      if UTF8_TEXT_EXTENSIONS.include?(extension&.downcase)
        each_utf8_text_chunk(file:, chunk_size: read_size) { |chunk| yield chunk }
      else
        while (chunk = file.read(read_size))
          yield Encodings.to_utf8(chunk)
        end
      end
    end

    def each_utf8_text_chunk(file:, chunk_size:)
      file.binmode if file.respond_to?(:binmode)
      file.set_encoding(Encoding::UTF_8)

      first_chunk = true

      file.each_line(chunk_size) do |chunk|
        chunk.scrub!("")
        Encodings.delete_bom!(chunk) if first_chunk
        first_chunk = false

        yield chunk if !chunk.empty?
      end
    end

    def first_chunk(text, chunk_tokens:, tokenizer:, splitters: ["\n\n", "\n", ".", ""])
      return text, " " if tokenizer.tokenize(text).length <= chunk_tokens

      splitters = splitters.find_all { |s| text.include?(s) }.compact

      buffer = +""
      split_char = nil

      splitters.each do |splitter|
        split_char = splitter

        text
          .split(split_char)
          .each do |part|
            break if tokenizer.tokenize(buffer + split_char + part).length > chunk_tokens
            buffer << split_char
            buffer << part
          end
        break if buffer.length > 0
      end

      [buffer, split_char]
    end

    def get_uploaded_file(upload:, target:)
      if %w[png jpg jpeg].include?(upload.extension) && !SiteSetting.ai_rag_images_enabled
        raise Discourse::InvalidAccess.new(
                "The setting ai_rag_images_enabled is false, can not index images",
              )
      end

      if upload.extension == "pdf"
        return(
          DiscourseAi::Utils::PdfToText.as_fake_file(
            upload: upload,
            llm_model: SiteSetting.ai_rag_images_enabled ? target.rag_llm_model : nil,
            user: Discourse.system_user,
          )
        )
      end

      if %w[png jpg jpeg].include?(upload.extension)
        return(
          DiscourseAi::Utils::ImageToText.as_fake_file(
            uploads: [upload],
            llm_model: target.rag_llm_model,
            user: Discourse.system_user,
          )
        )
      end

      store = Discourse.store

      @file ||=
        if store.external?
          # Upload#filesize could be approximate.
          # add two extra Mbs to make sure that we'll be able to download the upload.
          max_filesize = upload.filesize + 2.megabytes
          path = store.download(upload, max_file_size_kb: max_filesize)
          File.open(path) if path
        else
          File.open(store.path_for(upload))
        end
    end
  end
end
