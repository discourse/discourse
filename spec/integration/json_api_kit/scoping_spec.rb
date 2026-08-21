# frozen_string_literal: true

require_relative "support"

RSpec.describe "a listing kept to other rows" do
  include_context "with a listing of topics"

  describe "the rows of another listing" do
    let(:scoped_to) { Topic.where(id: middle.id) }

    it "renders only the rows that listing holds" do
      expect(document).to eq(
        data: [topic_object(middle, cursor: cursor_at(0))],
        included: [],
        links: links_of,
      )
    end

    context "when that listing holds no row" do
      let(:scoped_to) { Topic.where(title: "No topic carries this title") }

      it "renders an empty listing" do
        expect(document).to eq(data: [], included: [], links: links_of)
      end
    end
  end

  describe "the rows a resource exposes" do
    let(:resource) do
      Class.new(JsonApiKit::Resource) do
        model Topic
        type :topics
        attribute :title
        scope { |guardian| Topic.secured(guardian).where(closed: true) }
      end
    end

    it "renders only the rows its scope allows" do
      expect(document).to eq(data: [], included: [], links: links_of)
    end

    context "when a row matches the scope" do
      fab!(:closed) { Fabricate(:topic, closed: true, title: "A topic nobody can answer") }

      it "renders that row" do
        expect(document).to eq(
          data: [topic_object(closed, fields: %w[title], cursor: cursor_at(0))],
          included: [],
          links: links_of,
        )
      end
    end

    context "when the resource declares no scope of its own" do
      let(:resource) { JsonApiKitSpec::TopicResource }

      it "renders every row of its model" do
        expect(document).to eq(
          data: [
            topic_object(newest, cursor: cursor_at(0)),
            topic_object(middle, cursor: cursor_at(1)),
            topic_object(oldest, cursor: cursor_at(2)),
          ],
          included: [],
          links: links_of,
        )
      end
    end
  end

  describe "the rows a resource exposes to the asker" do
    let(:resource) do
      Class.new(JsonApiKit::Resource) do
        model Topic
        type :topics
        attribute :title
        scope { |guardian| Topic.where(user_id: guardian.user&.id) }
      end
    end

    it "renders no row for a guardian without a user" do
      expect(document).to eq(data: [], included: [], links: links_of)
    end

    context "when the guardian owns a row" do
      let(:guardian) { middle.user.guardian }

      it "renders that row" do
        expect(document).to eq(
          data: [topic_object(middle, fields: %w[title], cursor: cursor_at(0))],
          included: [],
          links: links_of,
        )
      end
    end
  end
end
