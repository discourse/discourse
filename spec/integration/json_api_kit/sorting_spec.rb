# frozen_string_literal: true

require_relative "support"

RSpec.describe "a sorted listing" do
  include_context "with a listing of topics"

  let(:sort) { { created_at: :asc } }
  let(:params) { { sort:, fields: { topics: [:title] } } }

  it "orders the rows by the sort of the request" do
    expect(document).to eq(
      data: [
        topic_object(oldest, fields: %w[title]),
        topic_object(middle, fields: %w[title]),
        topic_object(newest, fields: %w[title]),
      ],
      included: [],
      links: links_of,
    )
  end

  context "when the sort is created_at desc" do
    let(:sort) { { created_at: :desc } }

    it "orders the rows in that direction" do
      expect(document).to eq(
        data: [
          topic_object(newest, fields: %w[title]),
          topic_object(middle, fields: %w[title]),
          topic_object(oldest, fields: %w[title]),
        ],
        included: [],
        links: links_of,
      )
    end
  end

  context "when the sort is title asc and created_at desc" do
    let(:sort) { { title: :asc, created_at: :desc } }

    it "orders the rows by each sort in turn" do
      expect(document).to eq(
        data: [
          topic_object(oldest, fields: %w[title]),
          topic_object(newest, fields: %w[title]),
          topic_object(middle, fields: %w[title]),
        ],
        included: [],
        links: links_of,
      )
    end
  end

  context "when the request holds no sort" do
    let(:params) { { fields: { topics: [:title] } } }

    it "orders the rows by the sort the resource declares" do
      expect(document).to eq(
        data: [
          topic_object(newest, fields: %w[title]),
          topic_object(middle, fields: %w[title]),
          topic_object(oldest, fields: %w[title]),
        ],
        included: [],
        links: links_of,
      )
    end
  end

  context "when the sort is a relationship" do
    fab!(:unfiled, :private_message_topic)

    let(:sort) { { "category.name" => :asc } }

    it "puts the row with no related row last" do
      expect(document).to eq(
        data: [
          topic_object(oldest, fields: %w[title]),
          topic_object(middle, fields: %w[title]),
          topic_object(newest, fields: %w[title]),
          topic_object(unfiled, fields: %w[title]),
        ],
        included: [],
        links: links_of,
      )
    end
  end

  context "when the sort is last_posted_at and one row holds none" do
    fab!(:never_posted) do
      Fabricate(:topic, title: "Nothing has been posted here", last_posted_at: nil)
    end

    before { [oldest, middle, newest].each { it.update_columns(last_posted_at: it.created_at) } }

    let(:sort) { { last_posted_at: :asc } }

    it "puts the row with no value last" do
      expect(document).to eq(
        data: [
          topic_object(oldest, fields: %w[title]),
          topic_object(middle, fields: %w[title]),
          topic_object(newest, fields: %w[title]),
          topic_object(never_posted, fields: %w[title]),
        ],
        included: [],
        links: links_of,
      )
    end

    context "when the sort is last_posted_at desc" do
      let(:sort) { { last_posted_at: :desc } }

      it "puts the row with no value last" do
        expect(document).to eq(
          data: [
            topic_object(newest, fields: %w[title]),
            topic_object(middle, fields: %w[title]),
            topic_object(oldest, fields: %w[title]),
            topic_object(never_posted, fields: %w[title]),
          ],
          included: [],
          links: links_of,
        )
      end
    end
  end
end
