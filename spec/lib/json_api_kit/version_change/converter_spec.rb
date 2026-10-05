# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Converter do
  subject(:converter) { described_class.new(:up, callable, names) }

  let(:callable) { ->(date, time) { "#{date} #{time}" } }
  let(:names) { [date_name, time_name] }
  let(:date_name) { JsonApiKit::Name::Field.new(value: "posted_date", type: "topics") }
  let(:time_name) { JsonApiKit::Name::Field.new(value: "posted_time", type: "topics") }

  describe ".for" do
    subject(:converter) { described_class.for(:up, callable, from: names, to: destinations) }

    let(:destinations) { [date_name.with(value: "posted_at")] }

    it "builds a converter for one destination" do
      expect(converter).to be_an_instance_of(described_class)
    end

    context "when the declaration has several destinations" do
      let(:destinations) { [date_name, time_name] }
      let(:callable) { ->(date, time) { [date, time] } }

      it "builds a tuple converter" do
        expect(converter).to be_an_instance_of(described_class::Tuple)
      end
    end

    context "when one attribute has an array value" do
      let(:callable) { ->(date, time) { [date, time] } }

      it "preserves the array as one attribute value" do
        expect(converter.call("2026-08-01", "00:00:00")).to eq(%w[2026-08-01 00:00:00])
      end
    end
  end

  describe ".new" do
    context "when the callable does not respond to call" do
      let(:callable) { nil }

      it { expect { converter }.to raise_error(ArgumentError, /up: must respond to call/) }
    end

    context "when the callable takes another count of values" do
      let(:callable) { ->(date) { date } }

      it { expect { converter }.to raise_error(ArgumentError, /up: must take 2 values/) }
    end

    context "when the callable takes any count of values" do
      let(:callable) { ->(*values) { values.join(" ") } }

      it { expect { converter }.not_to raise_error }
    end

    context "when the callable is an object with a call method" do
      let(:callable) { Class.new { def call(date, time) = "#{date} #{time}" }.new }

      it { expect { converter }.not_to raise_error }
    end
  end

  describe "#call" do
    subject(:conversion) { converter.call("2026-08-01", "00:00:00") }

    it "returns the value the callable builds" do
      expect(conversion).to eq("2026-08-01 00:00:00")
    end

    context "when the callable raises" do
      subject(:conversion) { converter.call("2026-13-45", "00:00:00") }

      let(:callable) { ->(date, _time) { Time.zone.parse(date) } }

      it "raises a failure with the names of the values" do
        expect { conversion }.to raise_error(described_class::Failure, /posted_date, posted_time/)
      end
    end
  end
end
