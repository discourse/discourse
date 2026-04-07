# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::WaitHandlers do
  describe ".for" do
    it "resolves registered handlers by wait type" do
      expect(described_class.for(:timer)).to eq(described_class::Timer)
      expect(described_class.for("webhook")).to eq(described_class::Webhook)
    end
  end

  describe ".for_execution" do
    fab!(:execution) do
      Fabricate(
        :discourse_workflows_execution,
        status: :waiting,
        waiting_config: {
          "wait_type" => "form",
        },
      )
    end

    it "resolves handlers from waiting_config wait_type" do
      expect(described_class.for_execution(execution)).to eq(described_class::Form)
    end

    it "raises for unknown wait types" do
      execution.update!(waiting_config: { "wait_type" => "mystery" })

      expect { described_class.for_execution(execution) }.to raise_error(
        ArgumentError,
        'Unknown wait type: "mystery"',
      )
    end

    it "raises when wait_type is missing" do
      execution.update!(waiting_config: {})

      expect { described_class.for_execution(execution) }.to raise_error(
        ArgumentError,
        "Unknown wait type: nil",
      )
    end
  end
end
