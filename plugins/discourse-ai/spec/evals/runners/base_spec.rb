# frozen_string_literal: true

require_relative "../../../evals/lib/runners/base"
require_relative "../../../evals/lib/runners/ai_helper"

RSpec.describe DiscourseAi::Evals::Runners::Base do
  describe ".build" do
    let!(:runner_class) do
      Class.new(described_class) do
        def self.can_handle?(feature)
          feature == "foo:bar"
        end

        def run(*)
          "ok"
        end
      end
    end

    after { described_class.unregister(runner_class) }

    it "returns a runner instance when a class supports the feature" do
      runner = described_class.build("foo:bar")

      expect(runner).to be_a(runner_class)
      expect(runner.feature).to eq("foo:bar")
    end

    it "returns nil when no runner supports the feature" do
      expect(described_class.build("unknown")).to be_nil
    end
  end
end
