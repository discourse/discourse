# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Split do
  subject(:split) { described_class.new(from: dimensions, to: [width, height], up:, down:) }

  let(:dimensions) { JsonApiKit::Name::Field.new(value: "dimensions", type: "images") }
  let(:width) { dimensions.with(value: "width") }
  let(:height) { dimensions.with(value: "height") }
  let(:up) { ->(dimensions) { dimensions } }
  let(:down) { ->(width, height) { [width, height] } }

  describe "#current_names" do
    it "returns the destination names in declaration order" do
      expect(split.current_names).to eq([width, height])
    end
  end

  describe "#previous_names" do
    it "returns the historical name" do
      expect(split.previous_names).to eq([dimensions])
    end
  end

  describe "#current_pairs" do
    subject(:current_pairs) { split.current_pairs({ dimensions => [640, 480] }) }

    it "pairs the converted values with the destination names" do
      expect(current_pairs).to eq([[width, 640], [height, 480]])
    end
  end

  describe "#previous_pairs" do
    subject(:previous_pairs) { split.previous_pairs(attributes) }

    let(:attributes) { { height => 480, width => 640 } }

    it "reconstructs the historical value in declaration order" do
      expect(previous_pairs).to eq([[dimensions, [640, 480]]])
    end

    context "when a destination is absent" do
      let(:attributes) { super().except(height) }
      let(:down) { ->(width, height) { width * height } }

      it "omits the historical attribute without converting an incomplete group" do
        expect(previous_pairs).to be_empty
      end
    end

    context "when every destination is absent" do
      let(:attributes) { {} }
      let(:down) { ->(width, height) { width * height } }

      it "omits the historical attribute" do
        expect(previous_pairs).to be_empty
      end
    end

    context "when a destination has a null value" do
      let(:attributes) { super().merge(height => nil) }

      it "passes the null value to the converter" do
        expect(previous_pairs).to eq([[dimensions, [640, nil]]])
      end
    end

    context "when every destination has a null value" do
      let(:attributes) { { width => nil, height => nil } }

      it "passes every null value to the converter" do
        expect(previous_pairs).to eq([[dimensions, [nil, nil]]])
      end
    end
  end
end
