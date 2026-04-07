# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseWorkflows::NodeType do
  describe ".inputs" do
    it "defaults to [:main]" do
      expect(described_class.inputs).to eq([:main])
    end
  end

  describe ".outputs" do
    it "defaults to [:main]" do
      expect(described_class.outputs).to eq([:main])
    end
  end

  describe ".branching?" do
    it "returns false when single output" do
      expect(described_class.branching?).to eq(false)
    end

    it "returns true when multiple outputs" do
      klass =
        Class.new(described_class) do
          def self.outputs
            [{ key: "true", label_key: "t" }, { key: "false", label_key: "f" }]
          end
        end
      expect(klass.branching?).to eq(true)
    end
  end

  describe "#execute" do
    it "raises NotImplementedError" do
      instance = described_class.new(configuration: {})
      exec_ctx = OpenStruct.new
      expect { instance.execute(exec_ctx) }.to raise_error(NotImplementedError)
    end
  end
end
