# frozen_string_literal: true

class DiscourseAi::Utils::PdfToText
  MAX_PDF_SIZE = 100.megabytes

  class Reader
    def initialize(upload:, user: nil, llm_model: nil, execution_context: nil)
      @extractor =
        DiscourseAi::Utils::PdfToText.new(
          upload: upload,
          user: user,
          llm_model: llm_model,
          execution_context:,
        )
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

  def self.as_fake_file(upload:, user: nil, llm_model: nil, execution_context: nil)
    Reader.new(upload: upload, user: user, llm_model: llm_model, execution_context:)
  end

  def initialize(upload:, user: nil, llm_model: nil, execution_context: nil)
    @upload = upload
    @user = user
    @llm_model = llm_model
    @execution_context = execution_context
  end

  def extract_text
    pdf_path =
      if upload.local?
        Discourse.store.path_for(upload)
      else
        Discourse.store.download(upload, max_file_size_kb: MAX_PDF_SIZE)
      end

    raise Discourse::InvalidParameters.new("Failed to download PDF") if pdf_path.nil?

    require "pdf/reader"

    PDF::Reader.open(pdf_path) { |reader| reader.pages.each { |page| yield page.text } }
  end
end
