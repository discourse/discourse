# frozen_string_literal: true

RSpec.describe CustomEmoji do
  describe "validations" do
    subject(:custom_emoji) { Fabricate.build(:custom_emoji) }

    it { is_expected.to validate_length_of(:group).is_at_most(described_class::MAX_GROUP_LENGTH) }
  end

  describe ".normalize_group" do
    it "returns nil for blank values" do
      expect(described_class.normalize_group(nil)).to be_nil
      expect(described_class.normalize_group("")).to be_nil
      expect(described_class.normalize_group("  ")).to be_nil
    end

    it "returns nil for the default group regardless of case" do
      expect(described_class.normalize_group("default")).to be_nil
      expect(described_class.normalize_group("Default")).to be_nil
      expect(described_class.normalize_group(" DEFAULT ")).to be_nil
    end

    it "strips and downcases any other group" do
      expect(described_class.normalize_group(" Fun ")).to eq("fun")
    end
  end
end
