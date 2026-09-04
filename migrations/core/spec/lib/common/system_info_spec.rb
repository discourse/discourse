# frozen_string_literal: true

RSpec.describe Migrations::SystemInfo do
  describe ".usable_cpus" do
    it "takes the tighter of the affinity- and quota-aware counts" do
      allow(Etc).to receive(:nprocessors).and_return(64) # host affinity
      allow(Concurrent).to receive(:available_processor_count).and_return(4.0) # CFS quota

      expect(described_class.usable_cpus).to eq(4)
    end

    it "floors a fractional quota and never reports fewer than one" do
      allow(Etc).to receive(:nprocessors).and_return(8)
      allow(Concurrent).to receive(:available_processor_count).and_return(0.5)

      expect(described_class.usable_cpus).to eq(1)
    end
  end
end
