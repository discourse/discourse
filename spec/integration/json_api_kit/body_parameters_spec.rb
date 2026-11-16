# frozen_string_literal: true

require_relative "support"

module JsonApiKitSpec
  class ConvertedTopicsController < JsonApiKit::BaseController
    resource :topics

    def create
      render json: {
               meta: {
                 parameters: request_body.parameters,
                 original: request_body.to_h,
               },
             },
             content_type: JsonApiKit::MediaType::JSON_API
    end
  end

  class RenameInputHeading < JsonApiKit::VersionChange
    version "2026-09-01"
    description "Discussion headings become headlines."

    resource :discussion_threads do
      renamed_attribute from: :heading, to: :headline
    end
  end

  class ConvertTopicInputs < JsonApiKit::VersionChange
    version "2026-09-02"
    description "Discussion threads become topics with current attribute shapes."

    renamed_type from: :discussion_threads, to: :topics

    resource :topics do
      renamed_attribute from: :headline,
                        to: :title,
                        up: ->(title) { title&.strip },
                        down: ->(title) { title }
      merged_attributes from: %i[width height],
                        to: :dimensions,
                        up: ->(width, height) { [Integer(width), Integer(height)] },
                        down: ->(dimensions) { dimensions }
      split_attribute from: :size,
                      to: %i[pixel_width pixel_height],
                      up: ->(size) { size },
                      down: ->(width, height) { [width, height] }
    end
  end
end

RSpec.describe JsonApiKitSpec::ConvertedTopicsController, type: :request do
  describe "#create" do
    let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
    let(:path) { "/api/converted-topics" }
    let(:document) { { "data" => { "type" => "discussionThreads", "attributes" => attributes } } }
    let(:attributes) { { "heading" => " Hello ", "position" => "12" } }
    let(:parsed_body) { JSON.parse(response.body) }
    let(:parameters) { parsed_body.dig("meta", "parameters") }
    let(:version_changes) do
      JsonApiKit::VersionChanges.new(
        [JsonApiKitSpec::RenameInputHeading, JsonApiKitSpec::ConvertTopicInputs].map do
          it.new(__FILE__)
        end,
      )
    end

    before do
      freeze_time(Date.new(2026, 9, 3))
      allow(JsonApiKit::VersionChanges).to receive(:core).and_return(version_changes)
      Rails.application.routes.disable_clear_and_finalize = true
      Rails.application.routes.draw do
        post "/api/converted-topics" => "json_api_kit_spec/converted_topics#create"
      end
      Rails.application.routes.disable_clear_and_finalize = false
      post path,
           params: document.to_json,
           headers: {
             "HTTP_API_VERSION" => version,
             "CONTENT_TYPE" => JsonApiKit::MediaType::JSON_API,
           }
    end

    after { Rails.application.reload_routes! }

    shared_examples "an invalid attribute input" do
      it "reports the error in the original body", :aggregate_failures do
        expect(response).to have_http_status(:bad_request)
        expect(parsed_body.fetch("errors")).to contain_exactly(
          a_hash_including("status" => "400", "source" => { "pointer" => pointer }),
        )
      end
    end

    it "supplies current parameters after applying version changes", :aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(parameters).to eq("title" => "Hello", "position" => "12")
    end

    it "retains the original document" do
      expect(parsed_body.dig("meta", "original")).to eq(document)
    end

    context "when the client uses the current version" do
      let(:version) { "2026-09-02" }
      let(:document) { { "data" => { "type" => "topics", "attributes" => attributes } } }
      let(:attributes) { { "title" => " Hello ", "position" => "12" } }

      it "preserves values for service casting and validation" do
        expect(parameters).to eq(attributes)
      end
    end

    context "when attributes are omitted" do
      let(:document) { { "data" => { "type" => "discussionThreads" } } }

      it "supplies no parameters" do
        expect(parameters).to eq({})
      end
    end

    context "when the query selects response fields" do
      let(:path) { "#{super()}?fields[discussionThreads]=heading" }

      it "retains all submitted parameters" do
        expect(parameters).to eq("title" => "Hello", "position" => "12")
      end
    end

    context "when an attribute is explicitly null" do
      let(:attributes) { { "heading" => nil } }

      it "preserves the explicit null" do
        expect(parameters).to eq("title" => nil)
      end
    end

    context "when an attribute contains structured values" do
      let(:attributes) { { "settings" => { "keepCase" => [false, nil, { "someKey" => "12" }] } } }

      it "preserves the nested keys and values" do
        expect(parameters).to eq(attributes)
      end
    end

    context "when a version merges attributes" do
      let(:attributes) { { "width" => "640", "height" => "480" } }

      it "supplies the merged value" do
        expect(parameters).to eq("dimensions" => [640, 480])
      end
    end

    context "when a version splits an attribute" do
      let(:attributes) { { "size" => [640, 480] } }

      it "supplies each current attribute" do
        expect(parameters).to eq("pixel_width" => 640, "pixel_height" => 480)
      end
    end

    context "when a later converter rejects a renamed value" do
      let(:attributes) { { "heading" => 42 } }
      let(:pointer) { "/data/attributes/heading" }

      it_behaves_like "an invalid attribute input"
    end

    context "when a split receives too few values" do
      let(:attributes) { { "size" => [640] } }
      let(:pointer) { "/data/attributes/size" }

      it_behaves_like "an invalid attribute input"
    end

    context "when a split receives no values" do
      let(:attributes) { { "size" => [] } }
      let(:pointer) { "/data/attributes/size" }

      it_behaves_like "an invalid attribute input"
    end

    context "when a split receives too many values" do
      let(:attributes) { { "size" => [640, 480, 10] } }
      let(:pointer) { "/data/attributes/size" }

      it_behaves_like "an invalid attribute input"
    end

    context "when an earlier change renamed the invalid split input" do
      let(:attributes) { { "legacySize" => [640] } }
      let(:pointer) { "/data/attributes/legacySize" }
      let(:version_changes) do
        JsonApiKit::VersionChanges.new(
          [
            Class
              .new(JsonApiKit::VersionChange) do
                version "2026-09-01"
                description "Legacy sizes become sizes."

                resource(:discussion_threads) { renamed_attribute from: :legacy_size, to: :size }
              end
              .new(__FILE__),
            *super().to_a,
          ],
        )
      end

      it_behaves_like "an invalid attribute input"

      it "describes the submitted attribute" do
        expect(parsed_body.fetch("errors").sole.fetch("detail")).to eq(
          "This version cannot convert the value of legacySize.",
        )
      end
    end

    context "when a merge converter rejects supplied values" do
      let(:attributes) { { "width" => "bad", "height" => "480" } }
      let(:pointer) { "/data/attributes" }

      it_behaves_like "an invalid attribute input"
    end

    context "when only one merge source was supplied" do
      let(:attributes) { { "height" => "bad" } }
      let(:pointer) { "/data/attributes/height" }

      it_behaves_like "an invalid attribute input"
    end

    context "when a later converter rejects a merged value" do
      let(:attributes) { { "width" => "640", "height" => "0" } }
      let(:pointer) { "/data/attributes" }
      let(:version_changes) do
        JsonApiKit::VersionChanges.new(
          super().to_a +
            [
              Class
                .new(JsonApiKit::VersionChange) do
                  version "2026-09-03"
                  description "Dimensions become an aspect ratio."

                  resource :topics do
                    renamed_attribute from: :dimensions,
                                      to: :aspect_ratio,
                                      up: ->(dimensions) { Rational(*dimensions) },
                                      down: ->(ratio) { [ratio.numerator, ratio.denominator] }
                  end
                end
                .new(__FILE__),
            ],
        )
      end

      it_behaves_like "an invalid attribute input"

      it "describes the original source attributes" do
        expect(parsed_body.fetch("errors").sole.fetch("detail")).to eq(
          "This version cannot convert the value of width, height.",
        )
      end
    end

    context "when the client supplies a name from a later version" do
      let(:attributes) { { "title" => "Hello" } }
      let(:pointer) { "/data/attributes/title" }

      it_behaves_like "an invalid attribute input"
    end

    context "when a name uses the wrong casing" do
      let(:attributes) { { "unknown_field" => "Hello" } }
      let(:pointer) { "/data/attributes/unknown_field" }

      it_behaves_like "an invalid attribute input"
    end

    context "when the invalid name contains pointer characters" do
      let(:attributes) { { "invalid/~Name" => "Hello" } }
      let(:pointer) { "/data/attributes/invalid~1~0Name" }

      it_behaves_like "an invalid attribute input"
    end

    context "when the attributes object is malformed" do
      let(:attributes) { [] }
      let(:pointer) { "/data/attributes" }

      it_behaves_like "an invalid attribute input"
    end
  end
end
