# frozen_string_literal: true

require_relative "../../../evals/lib/runners/translation"

RSpec.describe DiscourseAi::Evals::Runners::Translation do
  fab!(:llm, :fake_model)

  let(:bot_double) { instance_double(DiscourseAi::Personas::Bot) }

  before do
    allow(AiPersona).to receive(:find_by_id_from_cache).and_return(nil)
    allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
  end

  describe "#run" do
    it "translates a single piece of content when no cases are provided" do
      runner = described_class.new("translation:post_raw_translator")
      allow(bot_double).to receive(:reply) { |_ctx, &blk| blk.call("Hola mundo", nil, nil) }

      eval_case = OpenStruct.new(args: { input: "Hello world", target_locale: "es" })

      expect(runner.run(eval_case, llm)).to eq("Hola mundo")
    end

    it "supports multiple cases and returns metadata for each entry" do
      runner = described_class.new("translation:short_text_translator")
      responses = %w[Hola Salut]
      allow(bot_double).to receive(:reply) do |_ctx, &blk|
        blk.call(responses.shift, nil, nil)
      end

      eval_case =
        OpenStruct.new(
          args: {
            target_locale: "es",
            cases: [{ input: "Hello" }, { input: "Hi there", target_locale: "fr" }],
          },
        )

      results = runner.run(eval_case, llm)

      expect(results.length).to eq(2)
      expect(results[0][:message]).to eq("Hello")
      expect(results[0][:target_locale]).to eq("es")
      expect(results[0][:result]).to eq("Hola")
      expect(results[1][:target_locale]).to eq("fr")
      expect(results[1][:result]).to eq("Salut")
    end

    it "invokes the locale detector without requiring a target locale" do
      runner = described_class.new("translation:locale_detector")
      allow(bot_double).to receive(:reply) { |_ctx, &blk| blk.call("es", nil, nil) }

      eval_case = OpenStruct.new(args: { input: "¿Cómo estás?" })

      expect(runner.run(eval_case, llm)).to eq("es")
    end

    it "raises when translation cases omit the target locale" do
      runner = described_class.new("translation:topic_title_translator")

      expect { runner.run(OpenStruct.new(args: { input: "Hello" }), llm) }.to raise_error(
        ArgumentError,
        /target_locale/,
      )
    end
  end
end
