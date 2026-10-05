# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Declaration::SplitAttribute do
  subject(:declaration) { described_class.new("images", from:, to:, up:, down:) }

  let(:from) { :dimensions }
  let(:to) { %i[width height] }
  let(:up) { ->(dimensions) { dimensions } }
  let(:down) { ->(width, height) { [width, height] } }
  let(:dimensions) { JsonApiKit::Name::Field.new(value: "dimensions", type: "images") }

  describe "#transformations" do
    subject(:transformations) { declaration.transformations }

    it "declares a split for the attribute only" do
      expect(transformations).to contain_exactly(
        an_instance_of(JsonApiKit::VersionChange::Split).and(
          having_attributes(
            previous_names: [dimensions],
            current_names: [dimensions.with(value: "width"), dimensions.with(value: "height")],
          ),
        ),
      )
    end

    context "when the source holds several names" do
      let(:from) { %i[dimensions other] }

      it "requires one source name" do
        expect { transformations }.to raise_error(described_class::Fault, /Declare one source name/)
      end
    end

    context "when the declaration holds one destination" do
      let(:to) { :width }

      it "requires at least two destinations" do
        expect { transformations }.to raise_error(
          described_class::Fault,
          /Declare at least two names/,
        )
      end
    end

    context "when two destinations have the same name" do
      let(:to) { [:width, "width"] }

      it "requires distinct destination names" do
        expect { transformations }.to raise_error(described_class::Fault, /Declare distinct names/)
      end
    end

    context "when a converter is not callable" do
      let(:up) { nil }

      it "reports the converter" do
        expect { transformations }.to raise_error(
          described_class::Fault,
          /up: must respond to call/,
        )
      end
    end

    context "when the up converter takes several values" do
      let(:up) { ->(width, height) { [width, height] } }

      it "requires one argument" do
        expect { transformations }.to raise_error(described_class::Fault, /up: must take 1 value/)
      end
    end

    context "when the down converter takes one value" do
      let(:down) { ->(dimensions) { dimensions } }

      it "requires one argument per destination" do
        expect { transformations }.to raise_error(
          described_class::Fault,
          /down: must take 2 values/,
        )
      end
    end
  end
end
