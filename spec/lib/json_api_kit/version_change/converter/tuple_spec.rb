# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Converter::Tuple do
  subject(:converter) { described_class.new(:up, callable, [dimensions], to: [width, height]) }

  let(:dimensions) { JsonApiKit::Name::Field.new(value: "dimensions", type: "images") }
  let(:width) { dimensions.with(value: "width") }
  let(:height) { dimensions.with(value: "height") }
  let(:callable) { ->(dimensions) { dimensions.map { Integer(it) } } }
  let(:input) { %w[640 480] }

  describe "#call" do
    subject(:conversion) { converter.call(input) }

    it "returns one value per destination in order" do
      expect(conversion).to eq([640, 480])
    end

    context "when a destination value is an array" do
      let(:callable) { ->(dimensions) { [dimensions, dimensions.reverse] } }

      it "preserves each attribute value" do
        expect(conversion).to eq([%w[640 480], %w[480 640]])
      end
    end

    context "when the destination values are null" do
      let(:callable) { ->(_dimensions) { [nil, nil] } }

      it "preserves the null values" do
        expect(conversion).to eq([nil, nil])
      end
    end

    context "when the callable returns too few values" do
      let(:callable) { ->(dimensions) { [dimensions.first] } }

      it "reports the expected output count" do
        expect { conversion }.to raise_error(
          ArgumentError,
          "up converter for dimensions must return 2 values (width, height). It returned 1.",
        )
      end
    end

    context "when the callable returns too many values" do
      let(:callable) { ->(dimensions) { [*dimensions, 10] } }

      it "reports the expected output count" do
        expect { conversion }.to raise_error(ArgumentError, /It returned 3\./)
      end
    end

    context "when the callable returns a scalar" do
      let(:callable) { ->(dimensions) { dimensions.first } }

      it "reports one value for several destinations" do
        expect { conversion }.to raise_error(ArgumentError, /It returned 1\./)
      end
    end

    context "when the callable returns null" do
      let(:callable) { ->(_dimensions) { nil } }

      it "reports no values for the destinations" do
        expect { conversion }.to raise_error(ArgumentError, /It returned 0\./)
      end
    end

    context "when the callable rejects the input" do
      let(:input) { %w[invalid 480] }

      it "reports a conversion failure with the source name" do
        expect { conversion }.to raise_error(
          JsonApiKit::VersionChange::Converter::Failure,
          "cannot convert the value of dimensions",
        )
      end
    end
  end
end
