# frozen_string_literal: true

require_relative "../../../evals/lib/runners/hyde"

RSpec.describe DiscourseAi::Evals::Runners::Hyde do
  fab!(:llm, :fake_model)

  let(:bot_double) { instance_double(DiscourseAi::Personas::Bot) }

  before do
    allow(AiPersona).to receive(:find_by_id_from_cache).and_return(nil)
    allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
    allow(bot_double).to receive(:reply) { |_ctx, &blk| blk.call("Hypothetical post", nil, nil) }
  end

  describe "#run" do
    it "returns a payload for a single query" do
      runner = described_class.new("hyde")
      result = runner.run(OpenStruct.new(args: { query: "How to theme Discourse" }), llm)

      expect(result[:result]).to eq("Hypothetical post")
      expect(result[:query]).to eq("How to theme Discourse")
    end

    it "evaluates multiple cases when provided" do
      runner = described_class.new("hyde")
      results =
        runner.run(
          OpenStruct.new(
            args: {
              cases: [{ query: "Discourse S3 backups" }, { query: "Plugins" }],
            },
          ),
          llm,
        )

      expect(results.length).to eq(2)
      expect(results.first[:result]).to eq("Hypothetical post")
      expect(results.first[:query]).to eq("Discourse S3 backups")
    end

    it "raises when the query is missing" do
      runner = described_class.new("hyde")

      expect { runner.run(OpenStruct.new(args: {}), llm) }.to raise_error(
        ArgumentError,
        /require :query/,
      )
    end
  end
end
