# frozen_string_literal: true

module JsonApiKitSpec
  class PartialImageResource < JsonApiKit::Resource
    model Topic
    type :images
    scope { |guardian| Topic.where(user_id: guardian.user.id) }

    attribute(:pixel_width) { it.posts_count }
    attribute(:pixel_height) { it.views }
    attribute(:caption) { it.title.split(":") }
    attribute(:unrelated) { raise "This attribute is not needed for conversion" }
  end

  class MergePartialImageFields < JsonApiKit::VersionChange
    version "2026-09-01"
    description "Image dimensions and captions become structured values."

    resource :pictures do
      merged_attributes from: %i[image_width image_height],
                        to: :dimensions,
                        up: ->(width, height) { [width, height] },
                        down: ->(dimensions) { dimensions }
      merged_attributes from: %i[caption_left caption_right],
                        to: :caption,
                        up: ->(left, right) { [left, right] },
                        down: ->(caption) { caption }
    end
  end

  class SplitPartialImageDimensions < JsonApiKit::VersionChange
    version "2026-09-02"
    description "Pictures become images with separate dimensions."

    renamed_type from: :pictures, to: :images

    resource :images do
      split_attribute from: :dimensions,
                      to: %i[pixel_width pixel_height],
                      up: ->(dimensions) { dimensions },
                      down: ->(width, height) { [width, height] }
      renamed_attribute from: :unrelated,
                        to: :unrelated_value,
                        up: ->(value) { value },
                        down: ->(_) { raise "Unrelated conversion" }
    end
  end
end

RSpec.describe "JSON:API partial attribute conversions" do
  subject(:converted) { edition.glossary.declared_attributes(attributes, existing:) }

  fab!(:author, :user)
  fab!(:topic) do
    Fabricate(
      :topic,
      user: author,
      title: "Left caption:Right caption",
      posts_count: 640,
      views: 480,
    )
  end

  let(:changes) do
    [JsonApiKitSpec::MergePartialImageFields, JsonApiKitSpec::SplitPartialImageDimensions].map do
      it.new(__FILE__)
    end
  end
  let(:edition) { JsonApiKit::Edition.new(changes) }
  let(:resource) { JsonApiKitSpec::PartialImageResource.new(guardian: author.guardian, edition:) }
  let(:existing) { edition.existing_values(resource:, id:) }
  let(:id) { topic.id }
  let(:attributes) { { field("imageWidth", type: "pictures") => 800 } }
  let(:reads) { track_sql_queries { converted }.grep(/FROM "topics"/) }

  before { id }

  def field(name, type: "images") = JsonApiKit::Name::Field.new(value: name, type:)

  it "completes the merge through the later split and type rename" do
    expect(converted).to eq(field("pixel_width") => 800, field("pixel_height") => 480)
  end

  context "when only the second source is supplied" do
    let(:attributes) { { field("imageHeight", type: "pictures") => 600 } }

    it "preserves the first position" do
      expect(converted).to eq(field("pixel_width") => 640, field("pixel_height") => 600)
    end
  end

  context "when a source is explicitly null" do
    let(:attributes) { { field("imageWidth", type: "pictures") => nil } }

    it "overrides the existing value" do
      expect(converted).to eq(field("pixel_width") => nil, field("pixel_height") => 480)
    end
  end

  context "when every source is supplied" do
    let(:attributes) { super().merge(field("imageHeight", type: "pictures") => 600) }
    let(:id) { 0 }

    it "converts without an existing record" do
      expect(converted).to eq(field("pixel_width") => 800, field("pixel_height") => 600)
    end

    it "does not query the record" do
      expect(reads).to be_empty
    end
  end

  context "when no conversion source is supplied" do
    let(:attributes) { { field("untouched", type: "pictures") => false } }
    let(:id) { 0 }

    it "leaves the conversion groups untouched" do
      expect(converted).to eq(field("untouched") => false)
    end

    it "does not query the record" do
      expect(reads).to be_empty
    end
  end

  context "when several groups need existing values" do
    let(:attributes) { super().merge(field("captionLeft", type: "pictures") => "New") }

    it "completes each affected group" do
      expect(converted).to eq(
        field("pixel_width") => 800,
        field("pixel_height") => 480,
        field("caption") => ["New", "Right caption"],
      )
    end

    it "loads the record once" do
      expect(reads).to contain_exactly(a_string_matching(/SELECT .*FROM "topics"/))
    end
  end

  context "when a later change also converts a destination value" do
    let(:attributes) { { field("imageHeight", type: "pictures") => 600 } }
    let(:changes) do
      super() +
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource :images do
                renamed_attribute from: :pixel_width,
                                  to: :canvas_width,
                                  up: ->(width) { width * 10 },
                                  down: ->(width) { width / 10 }
              end
            end
            .new(__FILE__),
        ]
    end
    let(:resource) do
      Class
        .new(JsonApiKit::Resource) do
          model Topic
          type :images
          attribute(:canvas_width) { it.posts_count * 10 }
          attribute(:pixel_height) { it.views }
        end
        .new(guardian: author.guardian, edition:)
    end

    it "recovers values through each later change" do
      expect(converted).to eq(field("canvas_width") => 6400, field("pixel_height") => 600)
    end
  end

  context "when a caller changes a current value" do
    let(:attributes) { { field("captionLeft", type: "pictures") => "New" } }

    before { existing.after(changes.last).fetch(field("caption")).clear }

    it "preserves the cached record value" do
      expect(converted).to eq(field("caption") => ["New", "Right caption"])
    end
  end

  context "when the record is outside the resource scope" do
    let(:resource) do
      JsonApiKitSpec::PartialImageResource.new(guardian: Fabricate(:user).guardian, edition:)
    end

    it "refuses the lookup" do
      expect { converted }.to raise_error(JsonApiKit::NotFound)
    end
  end

  context "when the existing height is unreadable" do
    let(:readable) { ->(_guardian) { false } }
    let(:resource) do
      permission = readable
      Class
        .new(JsonApiKit::Resource) do
          model Topic
          type :images
          attribute(:pixel_width) { it.posts_count }
          attribute(:pixel_height, readable: permission) { it.views }
        end
        .new(guardian: author.guardian, edition:)
    end

    it "reports an unreadable attribute" do
      expect { converted }.to raise_error(JsonApiKit::Resource::UnreadableAttribute)
    end

    context "when readability depends on the record" do
      let(:readable) { ->(_guardian, record) { record.views < 100 } }

      it "reports an unreadable attribute" do
        expect { converted }.to raise_error(JsonApiKit::Resource::UnreadableAttribute)
      end
    end

    context "when every source is supplied" do
      let(:attributes) { super().merge(field("imageHeight", type: "pictures") => 600) }

      it "converts without reading existing values" do
        expect(converted).to eq(field("pixel_width") => 800, field("pixel_height") => 600)
      end
    end
  end

  context "when a down converter modifies a current value" do
    let(:attributes) { { field("captionLeft", type: "pictures") => "New" } }
    let(:changes) do
      [
        Class
          .new(JsonApiKit::VersionChange) do
            resource :pictures do
              merged_attributes from: %i[caption_left caption_right],
                                to: :caption,
                                up: ->(left, right) { [left, right] },
                                down: ->(caption) { caption.reverse! }
            end
          end
          .new(__FILE__),
        super().last,
      ]
    end

    before { converted }

    it "preserves the current value" do
      expect(existing.after(changes.last).fetch(field("caption"))).to eq(
        ["Left caption", "Right caption"],
      )
    end
  end

  context "when existing values cannot be converted to the earlier version" do
    let(:changes) do
      [
        super().first,
        Class
          .new(JsonApiKit::VersionChange) do
            renamed_type from: :pictures, to: :images

            resource :images do
              split_attribute from: :dimensions,
                              to: %i[pixel_width pixel_height],
                              up: ->(dimensions) { dimensions },
                              down: ->(*) { raise ArgumentError, "Cannot reconstruct dimensions" }
            end
          end
          .new(__FILE__),
      ]
    end

    it "reports an existing-value conversion failure" do
      expect { converted }.to raise_error(JsonApiKit::ExistingValues::ConversionFailure)
    end
  end
end
