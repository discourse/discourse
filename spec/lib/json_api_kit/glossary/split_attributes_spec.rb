# frozen_string_literal: true

RSpec.describe JsonApiKit::Glossary do
  subject(:glossary) { described_class.resource(JsonApiKit::Timeline::FIRST_RELEASE) }

  let(:size) { JsonApiKit::Name::Field.new(value: "sizePair", type: "pictures") }
  let(:width) { JsonApiKit::Name::Field.new(value: "image_width", type: "images") }
  let(:height) { width.with(value: "image_height") }
  let(:up) { ->(dimensions) { dimensions.map { Integer(it) } } }
  let(:down) { ->(width, height) { [width, height] } }
  let(:rename) do
    Class
      .new(JsonApiKit::VersionChange) do
        version "2026-09-01"
        description "The size_pair attribute becomes pixel_dimensions."

        resource :pictures do
          renamed_attribute from: :size_pair, to: :pixel_dimensions
        end
      end
      .new(__FILE__)
  end
  let(:split) do
    converter_up = up
    converter_down = down

    Class
      .new(JsonApiKit::VersionChange) do
        version "2026-09-02"
        description "The dimensions become width and height."

        resource :pictures do
          split_attribute from: :pixel_dimensions,
                          to: %i[pixel_width pixel_height],
                          up: converter_up,
                          down: converter_down
        end
      end
      .new(__FILE__)
  end
  let(:later_change) do
    Class
      .new(JsonApiKit::VersionChange) do
        version "2026-09-03"
        description "Pictures become images with new attribute names."

        renamed_type from: :pictures, to: :images

        resource :images do
          renamed_attribute from: :pixel_width, to: :image_width
          renamed_attribute from: :pixel_height, to: :image_height
        end
      end
      .new(__FILE__)
  end
  let(:changes) { [rename, split, later_change] }
  let(:version_changes) { JsonApiKit::VersionChanges.new(changes) }

  before { allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes) }

  describe "#declared_names" do
    subject(:declared_names) { glossary.declared_names(size) }

    it "expands the historical name through the later renames" do
      expect(declared_names).to eq([width, height])
    end

    context "when the field belongs to a later version" do
      let(:size) { super().with(value: "pixelWidth") }

      it "reports the name available to the client" do
        expect { declared_names }.to raise_error(
          described_class::NotAMemberName,
          "Use sizePair, not pixelWidth.",
        )
      end
    end

    context "when the client uses the wrong casing" do
      let(:size) { super().with(value: "size_pair") }

      it "reports the historical name with its casing" do
        expect { declared_names }.to raise_error(
          described_class::NotAMemberName,
          "Use sizePair, not size_pair.",
        )
      end
    end
  end

  describe "#declared_attributes" do
    subject(:declared_attributes) { glossary.declared_attributes(attributes) }

    let(:attributes) { { size => %w[640 480] } }

    it "converts the old value into both current attributes" do
      expect(declared_attributes).to eq(width => 640, height => 480)
    end

    context "when the old attribute is absent" do
      let(:attributes) { {} }

      it "does not produce either destination" do
        expect(declared_attributes).to be_empty
      end
    end

    context "when the old value is null" do
      let(:attributes) { { size => nil } }
      let(:up) { ->(dimensions) { dimensions || [nil, nil] } }

      it "uses the converter's null representation" do
        expect(declared_attributes).to eq(width => nil, height => nil)
      end
    end

    context "when the split converter rejects the value" do
      let(:attributes) { { size => %w[invalid 480] } }

      it "reports the attribute under the client's name" do
        expect { declared_attributes }.to raise_error(
          described_class::BadValue,
          "This version cannot convert the value of sizePair.",
        )
      end
    end

    context "when the split converter returns too few values" do
      let(:up) { ->(dimensions) { [dimensions.first] } }

      it "reports an invalid converter result" do
        expect { declared_attributes }.to raise_error(
          ArgumentError,
          "up converter for pixel_dimensions must return 2 values (pixel_width, pixel_height). It returned 1.",
        )
      end
    end

    context "when a later converter rejects both split destinations" do
      let(:later_change) do
        Class
          .new(JsonApiKit::VersionChange) do
            version "2026-09-03"
            description "The dimensions become an area."

            resource :pictures do
              merged_attributes from: %i[pixel_width pixel_height],
                                to: :area,
                                up: ->(_width, _height) { raise ArgumentError },
                                down: ->(area) { [area, 1] }
            end
          end
          .new(__FILE__)
      end

      it "reports the historical source once" do
        expect { declared_attributes }.to raise_error(
          described_class::BadValue,
          "This version cannot convert the value of sizePair.",
        )
      end
    end
  end

  describe "#member_attributes" do
    subject(:member_attributes) { glossary.member_attributes(attributes) }

    let(:attributes) { { height => 480, width => 640 } }

    it "combines the current values through the earlier renames" do
      expect(member_attributes).to eq(size => [640, 480])
    end

    context "when a destination is absent" do
      let(:attributes) { super().except(height) }

      it "omits the historical attribute" do
        expect(member_attributes).to be_empty
      end
    end

    context "when the resource type has another attribute with the same name" do
      let(:attributes) { super().merge(width.with(type: "other_images") => 20) }

      it "preserves the unrelated attribute" do
        expect(member_attributes).to eq(
          size => [640, 480],
          width.with(value: "imageWidth", type: "otherImages") => 20,
        )
      end
    end
  end

  context "when a later change merges the destinations" do
    let(:later_change) do
      Class
        .new(JsonApiKit::VersionChange) do
          version "2026-09-03"
          description "The width and height become dimensions."

          resource :pictures do
            merged_attributes from: %i[pixel_width pixel_height],
                              to: :dimensions,
                              up: ->(width, height) { [width, height] },
                              down: ->(dimensions) { dimensions }
          end
        end
        .new(__FILE__)
    end
    let(:dimensions) { size.with(value: "dimensions") }

    describe "#declared_names" do
      it "returns the merged destination once" do
        expect(glossary.declared_names(size)).to eq([dimensions])
      end
    end

    describe "#declared_attributes" do
      it "splits the source before merging its destinations" do
        expect(glossary.declared_attributes(size => %w[640 480])).to eq(dimensions => [640, 480])
      end
    end

    describe "#member_attributes" do
      it "reconstructs the source after reversing the merge" do
        expect(glossary.member_attributes(dimensions => [640, 480])).to eq(size => [640, 480])
      end
    end
  end
end
