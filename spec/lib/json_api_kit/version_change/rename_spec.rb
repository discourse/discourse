# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Rename do
  subject(:rename) { described_class.new(from: old_name, to: new_name, up:, down:) }

  let(:up) { JsonApiKit::VersionChange::Declaration::NO_CONVERSION }
  let(:down) { JsonApiKit::VersionChange::Declaration::NO_CONVERSION }
  let(:old_name) { JsonApiKit::Name::Field.new(value: "posted_at", type: "topics") }
  let(:new_name) { JsonApiKit::Name::Field.new(value: "created_at", type: "topics") }

  describe "#current" do
    it "returns the new name" do
      expect(rename.current).to eq(new_name)
    end
  end

  describe "#current_pairs" do
    subject(:current_pairs) { rename.current_pairs(old_name => value) }

    let(:value) { "2026/08/01" }

    it "returns one pair, the new name with the value" do
      expect(current_pairs).to eq([[new_name, "2026/08/01"]])
    end

    context "when the rename converts the value" do
      let(:down) { ->(date) { date.to_s.tr("-", "/") } }
      let(:up) { ->(date) { date.to_s.tr("/", "-") } }

      it "returns the new name with the converted value" do
        expect(current_pairs).to eq([[new_name, "2026-08-01"]])
      end

      context "when the value is null" do
        let(:value) { nil }

        it "gives the converter the null value" do
          expect(current_pairs).to eq([[new_name, ""]])
        end
      end
    end
  end

  describe "#previous_names" do
    it "returns the old name" do
      expect(rename.previous_names).to eq([old_name])
    end
  end

  describe "#previous_pairs" do
    subject(:previous_pairs) { rename.previous_pairs(value) }

    let(:value) { "2026-08-01" }

    it "returns one pair, the old name with the value" do
      expect(previous_pairs).to eq([[old_name, "2026-08-01"]])
    end

    context "when the rename converts the value" do
      let(:down) { ->(date) { date.to_s.tr("-", "/") } }
      let(:up) { ->(date) { date.tr("/", "-") } }

      it "returns the old name with the converted value" do
        expect(previous_pairs).to eq([[old_name, "2026/08/01"]])
      end

      context "when the value is null" do
        let(:value) { nil }

        it "gives the converter the null value" do
          expect(previous_pairs).to eq([[old_name, ""]])
        end
      end
    end
  end
end
