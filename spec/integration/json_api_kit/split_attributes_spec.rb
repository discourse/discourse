# frozen_string_literal: true

module JsonApiKitSpec
  class SplitImage < Upload
    def get_dimension(key) = self[key]
  end

  class SplitImageResource < JsonApiKit::Resource
    model SplitImage
    type :images

    attribute :original_filename
    attribute :width, readable: ->(guardian) { guardian.user.present? }
    attribute :height, readable: ->(guardian, upload) { upload.user_id == guardian.user&.id }
  end

  class SplitImageOwnerResource < JsonApiKit::Resource
    model User
    type :users

    attribute :username
    has_many :uploads, resource: SplitImageResource
    includes "uploads"
  end

  class SplitImagesController < JsonApiKit::BaseController
    resource SplitImageResource
  end

  class SplitImageOwnersController < JsonApiKit::BaseController
    resource SplitImageOwnerResource
  end

  class SplitPictureDimensions < JsonApiKit::VersionChange
    version "2026-09-01"
    description "The pixel_dimensions attribute becomes pixel_width and pixel_height."

    resource :pictures do
      split_attribute from: :pixel_dimensions,
                      to: %i[pixel_width pixel_height],
                      up: ->(dimensions) { dimensions },
                      down: ->(width, height) { [width, height] }
    end
  end

  class RenameSplitPictureFields < JsonApiKit::VersionChange
    version "2026-09-02"
    description "Pictures become images with width and height attributes."

    renamed_type from: :pictures, to: :images

    resource :images do
      renamed_attribute from: :pixel_width, to: :width
      renamed_attribute from: :pixel_height, to: :height
    end
  end
end

RSpec.describe "JSON:API split attributes", type: :request do
  fab!(:owner, :user)
  fab!(:other_user, :user)
  fab!(:upload) { Fabricate(:upload, user: owner, width: 640, height: 480) }

  let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
  let(:user) { owner }
  let(:dimensions) { { width: 640, height: 480 } }
  let(:path) { "/api/images/#{upload.id}" }
  let(:query) { { "fields" => { "pictures" => "pixelDimensions" } } }
  let(:version_changes) do
    JsonApiKit::VersionChanges.new(
      [
        JsonApiKitSpec::SplitPictureDimensions.new(__FILE__),
        JsonApiKitSpec::RenameSplitPictureFields.new(__FILE__),
      ],
    )
  end
  let(:body) { JSON.parse(response.body) }
  let(:primary) { body.fetch("data") }
  let(:attributes) { primary.fetch("attributes", {}) }

  before do
    freeze_time(Date.new(2026, 9, 3))
    allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
    upload.update_columns(dimensions)
    sign_in(user) if user
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/images/:id" => "json_api_kit_spec/split_images#show"
      get "/api/image-owners/:id" => "json_api_kit_spec/split_image_owners#show"
    end
    Rails.application.routes.disable_clear_and_finalize = false
  end

  after { Rails.application.reload_routes! }

  describe "GET resource" do
    before { get path, headers: { "HTTP_API_VERSION" => version }, params: query }

    it "reconstructs only the selected historical attribute" do
      expect(attributes).to eq("pixelDimensions" => [640, 480])
    end

    it "uses the historical resource type" do
      expect(primary.fetch("type")).to eq("pictures")
    end

    context "when the request excludes the split attribute" do
      let(:query) { { "fields" => { "pictures" => "originalFilename" } } }

      it "returns only the selected attribute" do
        expect(attributes).to eq("originalFilename" => upload.original_filename)
      end
    end

    context "when the request selects no attributes" do
      let(:query) { { "fields" => { "pictures" => "" } } }

      it "returns no attributes" do
        expect(attributes).to be_empty
      end
    end

    context "when the request has no fieldset" do
      let(:query) { {} }

      it "returns the reconstructed attribute with the other readable attributes" do
        expect(attributes).to eq(
          "originalFilename" => upload.original_filename,
          "pixelDimensions" => [640, 480],
        )
      end
    end

    context "when one destination is unreadable" do
      let(:user) { other_user }
      let(:query) { { "fields" => { "pictures" => "pixelDimensions,originalFilename" } } }

      it "omits the historical attribute" do
        expect(attributes).to eq("originalFilename" => upload.original_filename)
      end

      it "accepts the fieldset" do
        expect(response).to have_http_status(:ok)
      end
    end

    context "when neither destination is readable" do
      let(:user) { nil }

      it "omits the historical attribute" do
        expect(attributes).to be_empty
      end
    end

    context "when one destination has a null value" do
      let(:dimensions) { super().merge(height: nil) }

      it "passes the null value to the converter" do
        expect(attributes).to eq("pixelDimensions" => [640, nil])
      end
    end

    context "when both destinations have null values" do
      let(:dimensions) { { width: nil, height: nil } }

      it "passes both null values to the converter" do
        expect(attributes).to eq("pixelDimensions" => [nil, nil])
      end
    end

    context "when an old client requests a destination name" do
      let(:query) { { "fields" => { "pictures" => "pixelWidth" } } }

      it "refuses the name with the historical attribute" do
        expect(body.fetch("errors").sole).to include(
          "detail" => "Use pixelDimensions, not pixelWidth.",
          "source" => {
            "parameter" => "fields[pictures]",
          },
        )
      end
    end

    context "when the pin includes the split but not the later renames" do
      let(:version) { "2026-09-01" }
      let(:query) { { "fields" => { "pictures" => "pixelHeight" } } }

      it "returns only the selected destination under its historical name" do
        expect(attributes).to eq("pixelHeight" => 480)
      end
    end

    context "when the client uses the current version" do
      let(:version) { "2026-09-02" }
      let(:query) { { "fields" => { "images" => "width" } } }

      it "returns only the selected current attribute" do
        expect(attributes).to eq("width" => 640)
      end
    end

    context "when the split resource is included" do
      let(:path) { "/api/image-owners/#{owner.id}" }
      let(:query) { super().merge("include" => "uploads") }

      it "reconstructs the selected attribute on the included resource" do
        expect(body.fetch("included").sole.fetch("attributes")).to eq(
          "pixelDimensions" => [640, 480],
        )
      end
    end
  end
end
