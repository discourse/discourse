# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Declaration::RenamedAttribute do
  subject(:declaration) { described_class.new("things", from: :label, to: :name, up:, down:) }

  let(:up) { described_class::NO_CONVERSION }
  let(:down) { described_class::NO_CONVERSION }

  describe "#transformations" do
    subject(:transformations) { declaration.transformations }

    it "returns a rename for the field, the sort and the anchor" do
      expect(transformations.map(&:from)).to eq(
        [
          JsonApiKit::Name::Field.new(value: "label", type: "things"),
          JsonApiKit::Name::Sort.new(value: "label", type: "things"),
          JsonApiKit::Name::Anchor.new(value: "label", type: "things"),
        ],
      )
    end

    it "gives each rename the new name" do
      expect(transformations.map { it.to.value }).to all(eq("name"))
    end

    context "when the declaration converts the value" do
      let(:up) { ->(label) { label.upcase } }
      let(:down) { ->(name) { name.downcase } }

      it "gives each rename the converters" do
        expect(transformations.map { it.up.call("a") }).to all(eq("A"))
      end
    end

    context "when the declaration holds one converter only" do
      let(:down) { ->(name) { name } }

      it "raises a fault with the change" do
        expect { transformations }.to raise_error(
          described_class::Fault,
          "Declare both up: and down:, to change label into name.",
        )
      end
    end

    context "when a converter does not respond to call" do
      let(:up) { nil }
      let(:down) { nil }

      it "raises a fault with the converter" do
        expect { transformations }.to raise_error(
          described_class::Fault,
          "up: must respond to call, to change label into name.",
        )
      end
    end

    context "when a converter takes another count of values" do
      let(:up) { ->(label) { label } }
      let(:down) { ->(name, other) { [name, other] } }

      it "raises a fault with the count it must take" do
        expect { transformations }.to raise_error(
          described_class::Fault,
          "down: must take 1 value, to change label into name.",
        )
      end
    end
  end
end
