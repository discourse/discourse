# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Declaration::MergedAttributes do
  subject(:declaration) { described_class.new("things", from:, to: :posted_at, up:, down:) }

  let(:from) { %i[posted_date posted_time] }
  let(:up) { ->(date, time) { "#{date} #{time}" } }
  let(:down) { ->(posted_at) { posted_at.to_s.split(" ") } }

  describe "#transformations" do
    subject(:transformations) { declaration.transformations }

    it "returns a merge for the field, the sort and the anchor" do
      expect(transformations.map(&:to)).to eq(
        [
          JsonApiKit::Name::Field.new(value: "posted_at", type: "things"),
          JsonApiKit::Name::Sort.new(value: "posted_at", type: "things"),
          JsonApiKit::Name::Anchor.new(value: "posted_at", type: "things"),
        ],
      )
    end

    it "gives each merge the old names in the order of the declaration" do
      expect(transformations.first.from).to eq(
        [
          JsonApiKit::Name::Field.new(value: "posted_date", type: "things"),
          JsonApiKit::Name::Field.new(value: "posted_time", type: "things"),
        ],
      )
    end

    it "gives each merge the converters" do
      expect(transformations.map { it.up.call("2026-08-01", "00:00:00") }).to all(
        eq("2026-08-01 00:00:00"),
      )
    end

    context "when the declaration holds one name" do
      let(:from) { :posted_date }

      it "raises a fault with the count of names it needs" do
        expect { transformations }.to raise_error(
          described_class::Fault,
          "Declare at least two names, to change posted_date into posted_at.",
        )
      end
    end

    context "when a converter does not respond to call" do
      let(:up) { nil }
      let(:down) { nil }

      it "raises a fault with the converter" do
        expect { transformations }.to raise_error(
          described_class::Fault,
          "up: must respond to call, to change posted_date, posted_time into posted_at.",
        )
      end
    end

    context "when the converter takes another count of values" do
      let(:up) { ->(date) { date } }

      it "raises a fault with the count it must take" do
        expect { transformations }.to raise_error(
          described_class::Fault,
          "up: must take 2 values, to change posted_date, posted_time into posted_at.",
        )
      end
    end
  end
end
