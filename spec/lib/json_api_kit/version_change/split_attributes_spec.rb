# frozen_string_literal: true

RSpec.describe JsonApiKit::VersionChange do
  subject(:version_change) { change_class.new("2026-09-01_split_dimensions.rb") }

  let(:change_class) do
    Class.new(described_class) do
      version "2026-09-01"
      description "The dimensions attribute becomes width and height."

      resource :images do
        split_attribute from: :dimensions,
                        to: %i[width height],
                        up: ->(dimensions) { dimensions },
                        down: ->(width, height) { [width, height] }
      end
    end
  end
  let(:dimensions) { JsonApiKit::Name::Field.new(value: "dimensions", type: "images") }
  let(:width) { dimensions.with(value: "width") }
  let(:height) { dimensions.with(value: "height") }

  describe "#verify!" do
    subject(:verify) { version_change.verify! }

    before { freeze_time(Date.new(2026, 9, 3)) }

    it "accepts the split declaration" do
      expect { verify }.not_to raise_error
    end

    context "when another declaration changes the source" do
      before { change_class.resource(:images) { renamed_attribute from: :dimensions, to: :size } }

      it "rejects the repeated source" do
        expect { verify }.to raise_error(ArgumentError, /changes dimensions twice/)
      end
    end

    context "when another declaration produces a destination" do
      before { change_class.resource(:images) { renamed_attribute from: :size, to: :height } }

      it "rejects the conflicting destination" do
        expect { verify }.to raise_error(ArgumentError, /changes two names into height/)
      end
    end

    context "when a relationship produces a destination" do
      before { change_class.resource(:images) { renamed_relationship from: :size, to: :height } }

      it "rejects the conflicting field name" do
        expect { verify }.to raise_error(ArgumentError, /changes two names into height/)
      end
    end
  end

  describe "#current_names" do
    subject(:current_names) { version_change.current_names(name) }

    let(:name) { dimensions }

    it "returns every destination in declaration order" do
      expect(current_names).to eq([width, height])
    end

    context "when the name belongs to another resource" do
      let(:name) { dimensions.with(type: "other_images") }

      it "preserves the unrelated name" do
        expect(current_names).to eq([name])
      end
    end

    context "when a sort has the historical attribute name" do
      let(:name) { JsonApiKit::Name::Sort.new(value: "dimensions", type: "images") }

      it "preserves the sort name" do
        expect(current_names).to eq([name])
      end
    end

    context "when an anchor has the historical attribute name" do
      let(:name) { JsonApiKit::Name::Anchor.new(value: "dimensions", type: "images") }

      it "preserves the anchor name" do
        expect(current_names).to eq([name])
      end
    end

    context "when the same change renames the resource type" do
      let(:name) { dimensions.with(type: "pictures") }

      before { change_class.renamed_type from: :pictures, to: :images }

      it "changes the owning type before expanding the field" do
        expect(current_names).to eq([width, height])
      end
    end
  end

  describe "#previous_names" do
    it "maps either destination to the historical source" do
      expect([width, height].map { version_change.previous_names(it) }).to eq(
        [[dimensions], [dimensions]],
      )
    end
  end

  describe "#previous_attributes" do
    subject(:previous_attributes) { version_change.previous_attributes(attributes) }

    let(:attributes) { { height => 480, width => 640 } }

    context "when the same change renames the resource type" do
      before { change_class.renamed_type from: :pictures, to: :images }

      it "reconstructs the field before translating its owning type" do
        expect(previous_attributes).to eq(dimensions.with(type: "pictures") => [640, 480])
      end
    end
  end
end
