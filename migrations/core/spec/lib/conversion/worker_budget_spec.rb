# frozen_string_literal: true

RSpec.describe Migrations::Conversion::WorkerBudget do
  describe ".available" do
    it "keeps the reserved cores back from the usable CPUs" do
      allow(Migrations::SystemInfo).to receive(:usable_cpus).and_return(20)

      expect(described_class.available).to eq(19) # reserve 1 by default
      expect(described_class.available(reserved: 4)).to eq(16)
    end

    it "never drops below a single worker" do
      allow(Migrations::SystemInfo).to receive(:usable_cpus).and_return(1)
      expect(described_class.available).to eq(1)
    end
  end
end
