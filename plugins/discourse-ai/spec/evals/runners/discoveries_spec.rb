# frozen_string_literal: true

require_relative "../../../evals/lib/runners/discoveries"

RSpec.describe DiscourseAi::Evals::Runners::Discoveries do
  fab!(:llm, :fake_model)

  let(:bot_double) { instance_double(DiscourseAi::Personas::Bot) }

  before do
    allow(AiPersona).to receive(:find_by_id_from_cache).and_return(nil)
    allow(DiscourseAi::Personas::Bot).to receive(:as).and_return(bot_double)
    allow(bot_double).to receive(:reply) { |_ctx, &blk| blk.call("Search overview", nil, nil) }
  end

  describe "#run" do
    it "returns a discovery payload with the model output" do
      runner = described_class.new("discoveries")
      result = runner.run(OpenStruct.new(args: { query: "chat integrations" }), llm)

      expect(result[:result]).to eq("Search overview")
      expect(result[:query]).to eq("chat integrations")
    end

    it "evaluates each provided case" do
      runner = described_class.new("discoveries")
      results =
        runner.run(
          OpenStruct.new(args: { cases: [{ query: "best themes" }, { query: "login security" }] }),
          llm,
        )

      expect(results.length).to eq(2)
      expect(results.last[:query]).to eq("login security")
    end

    it "raises when the query is missing" do
      runner = described_class.new("discoveries")

      expect { runner.run(OpenStruct.new(args: {}), llm) }.to raise_error(
        ArgumentError,
        /require :query/,
      )
    end
  end
end
