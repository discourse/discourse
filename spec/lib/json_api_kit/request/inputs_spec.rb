# frozen_string_literal: true

RSpec.describe JsonApiKit::Request::Inputs do
  subject(:inputs) { described_class.new(request, resource:) }

  let(:request) { instance_double(ActionDispatch::Request, **request_attributes) }
  let(:request_attributes) do
    { query_parameters: parameters, raw_post: json, request_method: "POST", path_parameters: {} }
  end
  let(:parameters) { { "fields" => { "topics" => "title" } } }
  let(:document) { { "data" => { "type" => "topics", "attributes" => { "title" => "A topic" } } } }
  let(:json) { document.to_json }
  let(:resource) do
    Class
      .new(JsonApiKit::Resource) do
        model Topic
        type :topics
        attribute :title
      end
      .new(guardian: Guardian.new)
  end

  describe ".new" do
    context "when the query and body are invalid" do
      let(:parameters) { { "unsupported" => true } }
      let(:json) { "{" }

      it "rejects the query before parsing the body" do
        expect { inputs }.to raise_error(JsonApiKit::Request::Invalid, /unsupported/)
      end
    end
  end

  describe "#query" do
    subject(:query) { inputs.query }

    it "leaves the request body unread" do
      query
      expect(request).not_to have_received(:raw_post)
    end

    context "when the body is not valid JSON" do
      let(:json) { "{" }

      it "supplies the query without parsing the body" do
        expect(query.to_h[:fields]).to eq("topics" => ["title"])
      end

      context "when the request updates a resource" do
        let(:request_attributes) do
          super().merge(request_method: "PATCH", path_parameters: { id: "42" })
        end

        it "supplies the query without preparing the update body" do
          expect(query.to_h[:fields]).to eq("topics" => ["title"])
        end
      end
    end
  end

  describe "#body" do
    subject(:body) { inputs.body }

    it "supplies the validated document" do
      expect(body.to_h).to eq(document)
    end

    context "when a POST route identifies a parent resource" do
      let(:request_attributes) { super().merge(path_parameters: { id: "42" }) }
      let(:document) { super().deep_merge("data" => { "id" => "42" }) }

      it "preserves the creation rules" do
        expect { body }.to raise_error(JsonApiKit::Request::Invalid, /client-generated IDs/)
      end
    end

    context "when the body is not valid JSON" do
      let(:json) { "{" }

      it "rejects the body when requested" do
        expect { body }.to raise_error(JsonApiKit::Request::Body::Unreadable)
      end
    end

    context "when the document has an invalid structure" do
      let(:document) { super().merge("data" => []) }

      it "rejects the document" do
        expect { body }.to raise_error(JsonApiKit::Request::Invalid, /data must be an object/)
      end
    end
  end
end
