# frozen_string_literal: true

class DiscourseAi::Utils::ImageToText
  BACKOFF_SECONDS = [5, 30, 60]
  MAX_IMAGE_SIZE = 10.megabytes

  class Reader
    def initialize(uploads:, llm_model:, user:)
      @uploads = uploads
      @llm_model = llm_model
      @user = user
      @buffer = +""

      @to_process = uploads.dup
    end

    # return nil if no more data
    def read(length)
      # for implementation simplicity we will process one image at a time
      if !@buffer.empty?
        part = @buffer.slice!(0, length)
        return part
      end

      return nil if @to_process.empty?

      upload = @to_process.shift
      extractor =
        DiscourseAi::Utils::ImageToText.new(upload: upload, llm_model: @llm_model, user: @user)
      extractor.extract_text do |chunk, error|
        if error
          Discourse.warn_exception(
            error,
            message: "Discourse AI: Failed to extract text from image",
          )
        else
          # this introduces chunk markers so discourse rag ingestion requires no overlaps
          @buffer << "\n[[metadata ]]\n"
          @buffer << chunk
        end
      end

      read(length)
    end
  end

  def self.as_fake_file(uploads:, llm_model:, user:)
    # given our implementation for extracting text expect a file, return a simple object that can simulate read(size)
    # and stream content
    Reader.new(uploads: uploads, llm_model: llm_model, user: user)
  end

  def self.tesseract_installed?
    if defined?(@tesseract_installed)
      @tesseract_installed
    else
      @tesseract_installed =
        begin
          Discourse::Utils.execute_command("which", "tesseract")
          true
        rescue Discourse::Utils::CommandError
          false
        end
    end
  end

  attr_reader :upload, :llm_model, :user

  def initialize(upload:, llm_model:, user:, guidance_text: nil)
    @upload = upload
    @llm_model = llm_model
    @user = user
    @guidance_text = guidance_text
  end

  def extract_text(retries: 3)
    uploads ||= @uploaded_pages

    raise "must specify a block" if !block_given?
    extracted = nil
    error = nil

    backoff = BACKOFF_SECONDS.dup

    retries.times do
      seconds = nil
      begin
        extracted = extract_text_from_page(upload)
        break
      rescue => e
        error = e
        seconds = backoff.shift || seconds
        sleep(seconds)
      end
    end
    if extracted
      extracted.each { |chunk| yield(chunk) }
    else
      yield(nil, error)
    end
    extracted || []
  end

  private

  def system_message
    <<~MSG
      OCR the following page into Markdown. Tables should be formatted as Github flavored markdown.
      Do not surround your output with triple backticks.

      Chunk the document into sections of roughly 250 - 1000 words. Our goal is to identify parts of the page with same semantic theme. These chunks will be embedded and used in a RAG pipeline.

      Always prefer returning text in Markdown vs HTML.
      Describe all the images and graphs you encounter.
      Only return text that will assist in the querying of data. Omit text such as "I had trouble recognizing images" and so on.

      Surround the chunks with <chunk> </chunk> html tags.
    MSG
  end

  def extract_text_from_page(page)
    raw_text = @guidance_text
    raw_text ||= extract_text_with_tesseract(page) if self.class.tesseract_installed?

    llm = llm_model.to_llm
    if raw_text.present?
      messages = [
        {
          type: :user,
          content: [
            "The following text was extracted from an image using OCR. Please enhance, correct, and structure this content while maintaining the original text:\n\n#{raw_text}",
            { upload_id: page.id },
          ],
        },
      ]
    else
      messages = [
        { type: :user, content: ["Please OCR the content in the image.", { upload_id: page.id }] },
      ]
    end
    prompt = DiscourseAi::Completions::Prompt.new(system_message, messages: messages)
    result = llm.generate(prompt, user: Discourse.system_user)
    extract_chunks(result)
  end

  def extract_text_with_tesseract(page)
    # return nil if we can not find tessaract binary
    return nil if !self.class.tesseract_installed?
    upload_path =
      if page.local?
        Discourse.store.path_for(page)
      else
        Discourse.store.download_safe(page, max_file_size_kb: MAX_IMAGE_SIZE)&.path
      end

    return "" if !upload_path || !File.exist?(upload_path)

    tmp_output_file = Tempfile.new(%w[tesseract_output .txt])
    tmp_output = tmp_output_file.path
    tmp_output_file.unlink

    command = [
      "tesseract",
      upload_path,
      tmp_output.sub(/\.txt$/, ""), # Tesseract adds .txt automatically
    ]

    success =
      Discourse::Utils.execute_command(
        *command,
        timeout: 20.seconds,
        failure_message: "Failed to OCR image with Tesseract",
      )

    if success && File.exist?("#{tmp_output}")
      text = File.read("#{tmp_output}")
      begin
        File.delete("#{tmp_output}")
      rescue StandardError
        nil
      end
      text.strip
    else
      Rails.logger.error("Tesseract OCR failed for #{upload_path}")
      ""
    end
  rescue => e
    Rails.logger.error("Error during OCR processing: #{e.message}")
    ""
  end

  def extract_chunks(text)
    return [] if text.nil? || text.empty?

    if text.include?("<chunk>") && text.include?("</chunk>")
      chunks = []
      remaining_text = text.dup

      while remaining_text.length > 0
        if remaining_text.start_with?("<chunk>")
          # Extract chunk content
          chunk_end = remaining_text.index("</chunk>")
          if chunk_end
            chunk = remaining_text[7..chunk_end - 1].strip
            chunks << chunk unless chunk.empty?
            remaining_text = remaining_text[chunk_end + 8..-1] || ""
          else
            # Malformed chunk - add remaining text and break
            chunks << remaining_text[7..-1].strip
            break
          end
        else
          # Handle text before next chunk if it exists
          next_chunk = remaining_text.index("<chunk>")
          if next_chunk
            text_before = remaining_text[0...next_chunk].strip
            chunks << text_before unless text_before.empty?
            remaining_text = remaining_text[next_chunk..-1]
          else
            # No more chunks - add remaining text and break
            chunks << remaining_text.strip
            break
          end
        end
      end

      return chunks.reject(&:empty?)
    end

    [text]
  end
end
