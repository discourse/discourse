# frozen_string_literal: true

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
      exec_ctx = Struct.new(:dummy).new
      expect { instance.execute(exec_ctx) }.to raise_error(NotImplementedError)
    end
  end

  describe ".available?" do
    it "defaults to true" do
      expect(described_class.available?).to eq(true)
    end

    it "can be overridden by subclass" do
      klass =
        Class.new(described_class) do
          def self.available?
            false
          end
        end
      expect(klass.available?).to eq(false)
    end
  end

  describe ".unavailable_reason_key" do
    it "defaults to nil" do
      expect(described_class.unavailable_reason_key).to be_nil
    end
  end
end
