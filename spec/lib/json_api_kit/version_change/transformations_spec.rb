# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange::Transformations do
  subject(:transformations) { described_class.new([split, rename]) }

  let(:dimensions) { JsonApiKit::Name::Field.new(value: "dimensions", type: "images") }
  let(:width) { dimensions.with(value: "width") }
  let(:height) { dimensions.with(value: "height") }
  let(:title) { dimensions.with(value: "title") }
  let(:caption) { dimensions.with(value: "caption") }
  let(:other) { dimensions.with(value: "original_filename") }
  let(:split_down) { ->(width, height) { [width, height] } }
  let(:split) do
    JsonApiKit::VersionChange::Split.new(
      from: dimensions,
      to: [width, height],
      up: ->(value) { value },
      down: split_down,
    )
  end
  let(:rename) do
    JsonApiKit::VersionChange::Rename.new(
      from: title,
      to: caption,
      up: ->(title) { title.upcase },
      down: ->(caption) { caption.downcase },
    )
  end

  describe "#current_names" do
    it "returns all destinations of a split" do
      expect(transformations.current_names(dimensions)).to eq([width, height])
    end
  end

  describe "#previous_names" do
    it "finds the source from either split destination" do
      expect([width, height].map { transformations.previous_names(it) }).to eq(
        [[dimensions], [dimensions]],
      )
    end
  end

  describe "#current_values" do
    subject(:current_values) { transformations.current_values(attributes) }

    let(:attributes) { { title => "photo", dimensions => [640, 480], other => nil } }

    it "returns the current attributes" do
      expect(current_values).to eq(caption => "PHOTO", width => 640, height => 480, other => nil)
    end

    context "when the collection is empty" do
      let(:transformations) { described_class.new([]) }

      it "preserves the attributes" do
        expect(current_values).to eq(attributes)
      end
    end

    context "when several attributes select one merge" do
      let(:transformations) { described_class.new([merge]) }
      let(:attributes) { { width => 640, height => 480 } }
      let(:merge_up) { ->(width, height) { [width, height] } }
      let(:merge) do
        JsonApiKit::VersionChange::Merge.new(
          from: [width, height],
          to: dimensions,
          up: merge_up,
          down: ->(value) { value },
        )
      end

      before { allow(merge_up).to receive(:call).and_call_original }

      it "applies the merge once" do
        current_values
        expect(merge_up).to have_received(:call).with(640, 480).once
      end

      it "combines the source values" do
        expect(current_values).to eq(dimensions => [640, 480])
      end
    end
  end

  describe "#previous_values" do
    subject(:previous_values) { transformations.previous_values(attributes) }

    let(:attributes) { { caption => "PHOTO", height => 480, width => 640, other => nil } }

    it "returns the historical attributes" do
      expect(previous_values).to eq(title => "photo", dimensions => [640, 480], other => nil)
    end

    context "when several attributes select one split" do
      before { allow(split_down).to receive(:call).and_call_original }

      it "applies the split once" do
        previous_values
        expect(split_down).to have_received(:call).with(640, 480).once
      end
    end

    context "when a split destination is absent" do
      let(:attributes) { super().except(height) }

      it "omits the incomplete historical attribute" do
        expect(previous_values).to eq(title => "photo", other => nil)
      end
    end

    context "when no attribute is present" do
      let(:attributes) { {} }

      it "produces no attributes" do
        expect(previous_values).to be_empty
      end
    end
  end

  describe "#verify!" do
    subject(:verify) { transformations.verify! }

    context "when a rename produces a split destination" do
      let(:rename) { super().with(to: height) }

      it "reports the conflicting destination" do
        expect { verify }.to raise_error(
          described_class::Conflict,
          "changes two names into height.",
        )
      end
    end

    context "when another resource has the same destination" do
      let(:rename) { super().with(to: height.with(type: "other_images")) }

      it "accepts the distinct names" do
        expect { verify }.not_to raise_error
      end
    end
  end
end
