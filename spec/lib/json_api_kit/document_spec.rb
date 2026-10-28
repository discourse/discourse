# frozen_string_literal: true

RSpec.describe JsonApiKit::Document do
  fab!(:topic) do
    Fabricate(:topic, title: "A topic a document renders", created_at: Time.utc(2026, 8, 1))
  end
  fab!(:other_topic) do
    Fabricate(:topic, title: "A topic a scope leaves out", created_at: Time.utc(2026, 8, 2))
  end

  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      sort :created_at
      default_sort created_at: :asc
      attribute :title
    end
  end
  let(:guardian) { Guardian.new }
  let(:edition) { JsonApiKit::Edition.current }
  let(:urls) do
    JsonApiKit::Urls.new(base: "https://example.com/api", current: "https://example.com/api/topics")
  end
  let(:client) { JsonApiKit::Client.new(guardian:, edition:, urls:) }
  let(:parameters) { {} }

  describe ".from" do
    subject(:document) { described_class.from(value) { { resource: instance, input:, client: } } }

    let(:resource) { Class.new(super()) { scope { Topic.none } } }
    let(:instance) { resource.new(guardian:, edition:) }
    let(:input) do
      JsonApiKit::Request::Input::Individual.new(parameters, resource: instance, edition:)
    end
    let(:rendered_ids) { document.to_h[:data].map { it[:id] } }

    context "when the input is a record" do
      let(:value) { topic }

      it "renders an individual resource" do
        expect(document.to_h[:data]).to include(id: topic.id.to_s)
      end
    end

    context "when the input is an array" do
      let(:value) { [other_topic, topic] }

      it "preserves the supplied order" do
        expect(rendered_ids).to eq([other_topic.id.to_s, topic.id.to_s])
      end
    end

    context "when the array contains one record" do
      let(:value) { [topic] }

      it "preserves the collection representation" do
        expect(rendered_ids).to eq([topic.id.to_s])
      end
    end

    context "when the array is empty" do
      let(:value) { [] }

      it "renders an empty collection" do
        expect(document.to_h[:data]).to eq([])
      end
    end

    context "when the input is a relation" do
      fab!(:excluded_topic) { Fabricate(:topic, created_at: Time.utc(2026, 8, 3)) }

      let(:value) { Topic.where(id: [topic.id, other_topic.id]).order(created_at: :desc) }

      it "preserves its selection and order" do
        expect(rendered_ids).to eq([other_topic.id.to_s, topic.id.to_s])
      end
    end

    context "when the input is an existing document" do
      subject(:document) { described_class.from(value) { raise "Unexpected request context" } }

      let(:value) { JsonApiKit::Document::Collection.for(parameters, resource:, client:) }

      it "returns the document without evaluating the context" do
        expect(document).to equal(value)
      end

      context "when the document contains errors" do
        let(:value) do
          JsonApiKit::Document::Errors.new(JsonApiKit::BadRequest.new("Invalid input"))
        end

        it "returns the errors without evaluating the context" do
          expect(document).to equal(value)
        end
      end
    end
  end

  describe "Collection.for" do
    subject(:document) do
      JsonApiKit::Document::Collection.for(parameters, resource:, client:, scoped_to:)
    end

    let(:scoped_to) { nil }
    let(:listed_ids) { document.to_h[:data].map { it[:id] } }

    it "renders every record of the listing" do
      expect(listed_ids).to eq([topic.id.to_s, other_topic.id.to_s])
    end

    it "returns the status of a rendered document" do
      expect(document.status).to eq("200")
    end

    context "when the resource supplies request context" do
      let(:instance) { resource.new(guardian:, edition:) }

      before do
        allow(resource).to receive(:new).and_return(instance)
        allow(JsonApiKit::Request::Input::Collection).to receive(:new).and_call_original
        allow(JsonApiKit::Query::Collection).to receive(:new).and_call_original
        document
      end

      it "uses the instance for input validation" do
        expect(JsonApiKit::Request::Input::Collection).to have_received(:new).with(
          parameters,
          resource: instance,
          edition:,
        )
      end

      it "uses the same instance for execution" do
        expect(JsonApiKit::Query::Collection).to have_received(:new).with(
          instance,
          an_instance_of(JsonApiKit::Request::Collection),
          scoped_to:,
        )
      end

      it "creates one instance for the request" do
        expect(resource).to have_received(:new).once
      end
    end

    context "when the request includes related records" do
      let(:parameters) { { include: "user" } }
      let(:users_resource) do
        Class.new(JsonApiKit::Resource) do
          model User
          type :users
          attribute :username
        end
      end
      let(:resource) { Class.new(super()).tap { it.has_one(:user, resource: users_resource) } }
      let(:users) { users_resource.new(guardian:, edition:) }

      before do
        allow(users_resource).to receive(:new).and_return(users)
        allow(JsonApiKit::Query::Collection).to receive(:new).and_call_original
        document
      end

      it "creates one resource instance for the related listing" do
        expect(users_resource).to have_received(:new).with(guardian:, edition:).once
      end

      it "queries the related records through that instance" do
        expect(JsonApiKit::Query::Collection).to have_received(:new).with(
          users,
          an_instance_of(JsonApiKit::Request::Collection),
          scoped_to: an_instance_of(JsonApiKit::Scoping::PerOwner),
        )
      end

      it "renders all related records" do
        expect(document.to_h[:included].map { it[:id] }).to contain_exactly(
          topic.user_id.to_s,
          other_topic.user_id.to_s,
        )
      end
    end

    context "when a caller narrows the listing with a scope" do
      let(:scoped_to) { Topic.where(id: topic.id) }

      it "renders the records that scope holds" do
        expect(listed_ids).to eq([topic.id.to_s])
      end
    end

    context "when the contract refuses the request" do
      let(:parameters) { { sort: { secrets: :asc } } }

      it { is_expected.to be_a(JsonApiKit::Document::Errors) }

      it "renders the error as a document" do
        expect(document.to_h[:errors].sole).to include(status: "400", title: "No such sort")
      end
    end
  end

  describe "Individual.for" do
    subject(:document) { JsonApiKit::Document::Individual.for(id, parameters, resource:, client:) }

    let(:id) { topic.id }

    it "renders the record as a document" do
      expect(document.to_h[:data][:id]).to eq(topic.id.to_s)
    end

    context "when the resource supplies request context" do
      let(:instance) { resource.new(guardian:, edition:) }

      before do
        allow(resource).to receive(:new).and_return(instance)
        allow(JsonApiKit::Request::Input::Individual).to receive(:new).and_call_original
        allow(JsonApiKit::Query::Individual).to receive(:new).and_call_original
        document
      end

      it "uses the instance for input validation" do
        expect(JsonApiKit::Request::Input::Individual).to have_received(:new).with(
          parameters,
          resource: instance,
          edition:,
        )
      end

      it "uses the same instance for execution" do
        expect(JsonApiKit::Query::Individual).to have_received(:new).with(
          instance,
          an_instance_of(JsonApiKit::Request::Individual),
        )
      end

      it "creates one instance for the request" do
        expect(resource).to have_received(:new).once
      end
    end

    context "when no row holds that id" do
      let(:id) { -1 }

      it { is_expected.to be_a(JsonApiKit::Document::Errors) }

      it "renders the error as a document" do
        expect(document.to_h[:errors].sole).to include(status: "404", title: "No such record")
      end
    end
  end
end
