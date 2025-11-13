# frozen_string_literal: true

require_relative "../../../evals/lib/runners/translation"
require_relative "../support/runner_helper"

RSpec.describe DiscourseAi::Evals::Runners::Translation do
  fab!(:llm, :fake_model)

  describe "#run" do
    it "translates a single piece of content when no cases are provided" do
      runner = described_class.new("post_raw_translator")
      stub_runner_bot(response: "Hola mundo")

      eval_case = OpenStruct.new(args: { input: "Hello world", target_locale: "es" })

      result = runner.run(eval_case, llm)

      expect(result[:raw]).to eq("Hola mundo")
      expect(result[:metadata]).to include(target_locale: "es")
    end

    it "supports multiple cases and returns metadata for each entry" do
      runner = described_class.new("short_text_translator")
      responses = %w[Hola Salut]
      stub_runner_bot { |blk| blk.call(responses.shift, nil, nil) }

      eval_case =
        OpenStruct.new(
          args: {
            target_locale: "es",
            cases: [{ input: "Hello" }, { input: "Hi there", target_locale: "fr" }],
          },
        )

      results = runner.run(eval_case, llm)

      expect(results.length).to eq(2)
      expect(results[0][:raw]).to eq("Hola")
      expect(results[0][:metadata]).to include(message: "Hello", target_locale: "es")
      expect(results[1][:metadata]).to include(target_locale: "fr", message: "Hi there")
      expect(results[1][:raw]).to eq("Salut")
    end

    it "invokes the locale detector without requiring a target locale" do
      runner = described_class.new("locale_detector")
      stub_runner_bot(response: "es")

      eval_case = OpenStruct.new(args: { input: "¿Cómo estás?" })

      expect(runner.run(eval_case, llm)[:raw]).to eq("es")
    end

    it "raises when translation cases omit the target locale" do
      runner = described_class.new("topic_title_translator")

      expect { runner.run(OpenStruct.new(args: { input: "Hello" }), llm) }.to raise_error(
        ArgumentError,
        /target_locale/,
      )
    end
  end
end
