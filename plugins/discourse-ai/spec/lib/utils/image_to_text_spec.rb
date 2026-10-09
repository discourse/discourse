# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::ImageToText do
  fab!(:llm_model)
  fab!(:upload)

  before { enable_current_plugin }

  describe "#extract_text" do
    it "combines multiple LLM text blocks before extracting chunks" do
      extractor =
        described_class.new(
          upload: upload,
          llm_model: llm_model,
          user: Discourse.system_user,
          guidance_text: "Extracted text",
        )
      chunks = []

      DiscourseAi::Completions::Llm.with_prepared_responses([["<chunk>First ", "block</chunk>"]]) do
        extractor.extract_text(retries: 1) { |chunk| chunks << chunk }
      end

      expect(chunks).to eq(["First block"])
    end
  end
end
