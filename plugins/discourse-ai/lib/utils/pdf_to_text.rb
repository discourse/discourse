# frozen_string_literal: true

class DiscourseAi::Utils::PdfToText
  MAX_PDF_SIZE = 100.megabytes

  class Reader
    def initialize(upload:, user: nil, llm_model: nil)
      @extractor =
        DiscourseAi::Utils::PdfToText.new(upload: upload, user: user, llm_model: llm_model)
      @enumerator = create_enumerator
      @buffer = +""
    end

    def read(length)
      return @buffer.slice!(0, length) if !@buffer.empty?

      begin
        @buffer << @enumerator.next
      rescue StopIteration
        return nil
      end

      @buffer.slice!(0, length)
    end

    private

    def create_enumerator
      Enumerator.new { |yielder| @extractor.extract_text { |chunk| yielder.yield(chunk || "") } }
    end
  end

  attr_reader :upload

  def self.as_fake_file(upload:, user: nil, llm_model: nil)
    Reader.new(upload: upload, user: user, llm_model: llm_model)
  end

  def initialize(upload:, user: nil, llm_model: nil)
    @upload = upload
    @user = user
    @llm_model = llm_model
  end

  def extract_text
    pdf_path =
      if upload.local?
        Discourse.store.path_for(upload)
      else
        Discourse.store.download_safe(upload, max_file_size_kb: MAX_PDF_SIZE)&.path
      end

    raise Discourse::InvalidParameters.new("Failed to download PDF") if pdf_path.nil?

    require "pdf/reader"

    page_number = 0
    PDF::Reader.open(pdf_path) do |reader|
      reader.pages.each do |page|
        page_number += 1
        llm_decorate(page_number: page_number, text: page.text, pdf_path: pdf_path) do |chunk|
          yield chunk
        end
      end
    end
  end

  def llm_decorate(page_number:, text:, pdf_path:)
    raise "Must be called with block" if !block_given?
    if !@llm_model
      yield text
      return
    end

    begin
      temp_dir = Dir.mktmpdir("discourse-pdf-#{SecureRandom.hex(8)}")
      output_path = File.join(temp_dir, "page-#{page_number}.png")

      # Extract specific page using ImageMagick
      # image magick uses 0 based page numbers
      command = [
        "magick",
        "-density",
        "300",
        "#{pdf_path}[#{page_number - 1}]",
        "-background",
        "white",
        "-auto-orient",
        "-quality",
        "85",
        output_path,
      ]

      Discourse::Utils.execute_command(
        *command,
        failure_message: "Failed to convert PDF page #{page_number} to image",
        timeout: 30,
      )

      # TODO - we are creating leftover uploads, they will be cleaned up
      # but maybe we should just keep them around?
      upload =
        UploadCreator.new(File.open(output_path), "page-#{page_number}.png").create_for(@user&.id)

      DiscourseAi::Utils::ImageToText
        .new(upload: upload, llm_model: @llm_model, user: @user, guidance_text: text)
        .extract_text { |chunk| yield chunk }
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir
    end
  end
end
