# frozen_string_literal: true

RSpec.describe GCStatInstrumenter do
  describe ".instrument" do
    it "returns a hash with the GC time, major and minor GC count for executing the given block" do
      result =
        described_class.instrument do
          GC.start(full_mark: true) # Major GC
          GC.start(full_mark: false) # Minor GC
        end

      expect(result[:gc]).to be_present
      expect(result[:gc][:time]).to be >= 0.0
      expect(result[:gc][:major_count]).to eq(1)
      expect(result[:gc][:minor_count]).to eq(1)
    end
  end
end
