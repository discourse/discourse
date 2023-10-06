# frozen_string_literal: true

RSpec.describe TrustLevel do
  describe "levels" do
    context "when verifying enum sequence" do
      before { @levels = TrustLevel.levels }

      it "'newuser' should be at 0 position" do
        expect(@levels[:newuser]).to eq(0)
      end

      it "'leader' should be at 4th position" do
        expect(@levels[:leader]).to eq(4)
      end
    end
  end

  describe "#<=>" do
    let(:trust_level) { described_class.new(1) }

    context "when comparing to an integer" do
      it { expect(trust_level <=> 0).to eq(1) }
      it { expect(trust_level <=> 1).to eq(0) }
      it { expect(trust_level <=> 2).to eq(-1) }
    end

    context "when comparing to a symbol" do
      it { expect(trust_level <=> :newuser).to eq(1) }
      it { expect(trust_level <=> :basic).to eq(0) }
      it { expect(trust_level <=> :member).to eq(-1) }
    end

    context "when comparing to another trust level" do
      it { expect(trust_level <=> described_class.new(0)).to eq(1) }
      it { expect(trust_level <=> described_class.new(1)).to eq(0) }
      it { expect(trust_level <=> described_class.new(2)).to eq(-1) }
    end
  end

  describe "#to_i" do
    it { expect(described_class.new(1).to_i).to eq(1) }
  end

  describe "#to_sym" do
    it { expect(described_class.new(1).to_sym).to eq(:basic) }
  end

  describe "#to_s" do
    it { expect(described_class.new(1).to_s).to eq("basic") }
  end

  describe "#name" do
    it { expect(described_class.new(1).name).to eq("basic user") }
  end

  describe "constructor methods" do
    it { expect(described_class.newuser.level).to eq(0) }
    it { expect(described_class.basic.level).to eq(1) }
    it { expect(described_class.member.level).to eq(2) }
    it { expect(described_class.regular.level).to eq(3) }
    it { expect(described_class.leader.level).to eq(4) }
  end

  describe "predicate methods" do
    it { expect(described_class.new(0)).to be_newuser }
    it { expect(described_class.new(1)).to be_basic }
    it { expect(described_class.new(2)).to be_member }
    it { expect(described_class.new(3)).to be_regular }
    it { expect(described_class.new(4)).to be_leader }
  end
end
