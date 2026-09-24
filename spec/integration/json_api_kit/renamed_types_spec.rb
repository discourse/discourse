# frozen_string_literal: true

require_relative "support"

module JsonApiKitSpec
  class RenamedTypesController < JsonApiKit::BaseController
    resource :topics
  end

  class RenameDiscussionFields < JsonApiKit::VersionChange
    version "2026-09-01"
    description "Discussion fields use new names."

    resource :discussion_threads do
      renamed_attribute from: :words,
                        to: :heading,
                        up: ->(words) { words.to_a.join(" ") },
                        down: ->(heading) { heading.to_s.split(" ") }
      merged_attributes from: %i[posted_date posted_time],
                        to: :posted_at,
                        up: ->(date, time) { Time.zone.parse("#{date}T#{time}Z") },
                        down: ->(time) { [time.to_date.iso8601, time.strftime("%H:%M:%S")] }
      renamed_sort from: :bumped_at, to: :last_posted_at
      renamed_filter from: :name, to: :title
    end
  end

  class RenameDiscussionsToArticles < JsonApiKit::VersionChange
    version "2026-09-02"
    description "Discussions become articles."

    resource :articles do
      renamed_attribute from: :heading, to: :subject
    end

    renamed_type from: :discussion_threads, to: :articles
    renamed_type from: :authors, to: :users
    renamed_type from: :teams, to: :groups
  end

  class RenameArticlesToTopics < JsonApiKit::VersionChange
    version "2026-09-03"
    description "Articles become topics."

    renamed_type from: :articles, to: :topics
  end

  class RenameTopicFieldsAfterType < JsonApiKit::VersionChange
    version "2026-09-04"
    description "Topic fields use their current names."

    resource :topics do
      renamed_attribute from: :subject, to: :title
      renamed_attribute from: :posted_at, to: :created_at
    end
  end
end

RSpec.describe "JSON:API type renames", type: :request do
  include_context "with a listing of topics"

  let(:changes) do
    [
      JsonApiKitSpec::RenameDiscussionFields,
      JsonApiKitSpec::RenameDiscussionsToArticles,
      JsonApiKitSpec::RenameArticlesToTopics,
      JsonApiKitSpec::RenameTopicFieldsAfterType,
    ].map { it.new(__FILE__) }
  end
  let(:version) { JsonApiKit::Timeline::FIRST_RELEASE.to_s }
  let(:parsed_body) { JSON.parse(response.body) }
  let(:primary) { parsed_body.fetch("data").first }
  let(:attributes) { primary.fetch("attributes") }
  let(:ids) { parsed_body.fetch("data").map { it.fetch("id") } }
  let(:error) { parsed_body.fetch("errors").sole }
  let(:author) { newest.user }
  let(:group_object) do
    parsed_body.fetch("included").detect { it["id"] == group.id.to_s && it["type"] == "teams" }
  end
  let(:author_object) do
    parsed_body.fetch("included").detect { it["id"] == author.id.to_s && it["type"] == "authors" }
  end

  fab!(:group)

  before do
    group.add(author)
    oldest.update_columns(last_posted_at: Time.utc(2026, 8, 3))
    middle.update_columns(last_posted_at: Time.utc(2026, 8, 1))
    newest.update_columns(last_posted_at: Time.utc(2026, 8, 2))
    freeze_time(Date.new(2026, 9, 5))
    allow(JsonApiKit::VersionChange).to receive(:all).and_return(changes)
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw do
      get "/api/topics" => "json_api_kit_spec/renamed_types#index"
      get "/api/topics/:id" => "json_api_kit_spec/renamed_types#show"
    end
    Rails.application.routes.disable_clear_and_finalize = false
    get "/api/topics", headers: { "HTTP_API_VERSION" => version }, params: query
  end

  after { Rails.application.reload_routes! }

  it "sends the historical type with its casing" do
    expect(primary.fetch("type")).to eq("discussionThreads")
  end

  it "reverses field changes across both type changes" do
    expect(attributes).to eq(
      "words" => newest.title.split(" "),
      "postedDate" => "2026-08-03",
      "postedTime" => "00:00:00",
    )
  end

  it "keeps the current resource URL" do
    expect(URI(primary.dig("links", "self")).path).to eq("/api/topics/#{newest.id}")
  end

  context "when the client follows the resource URL" do
    before { get primary.dig("links", "self"), headers: { "HTTP_API_VERSION" => version } }

    it "serves the historical representation" do
      expect(JSON.parse(response.body).fetch("data")).to include(
        "type" => "discussionThreads",
        "id" => newest.id.to_s,
      )
    end
  end

  context "when the request includes renamed related resources" do
    let(:query) { { "include" => "user.groups,category" } }

    it "uses the historical type in to-one linkage" do
      expect(primary.dig("relationships", "user", "data")).to eq(
        "type" => "authors",
        "id" => author.id.to_s,
      )
    end

    it "uses the historical type in to-many linkage" do
      expect(author_object.dig("relationships", "groups", "data")).to include(
        "type" => "teams",
        "id" => group.id.to_s,
      )
    end

    it "includes the resources named by the linkage" do
      expect(parsed_body.fetch("included")).to include(
        a_hash_including("type" => "authors", "id" => author.id.to_s),
        a_hash_including("type" => "teams", "id" => group.id.to_s),
      )
    end

    it "preserves an unrelated resource" do
      expect(parsed_body.fetch("included")).to include(
        a_hash_including(
          "type" => "categories",
          "id" => newest.category.id.to_s,
          "attributes" => {
            "name" => newest.category.name,
          },
        ),
      )
    end

    context "when the fieldsets exclude related attributes" do
      let(:query) { super().merge("fields" => { "authors" => "groups", "teams" => "" }) }

      it "keeps the included identities without their attributes" do
        expect(author_object).not_to have_key("attributes")
      end

      it "excludes the attributes of the to-many resource" do
        expect(group_object).not_to have_key("attributes")
      end

      it "keeps the to-many linkage without related attributes" do
        expect(author_object.dig("relationships", "groups", "data")).to include(
          "type" => "teams",
          "id" => group.id.to_s,
        )
      end

      it "keeps the relationship linkage" do
        expect(primary.dig("relationships", "user", "data")).to eq(
          "type" => "authors",
          "id" => author.id.to_s,
        )
      end
    end
  end

  context "when the request selects a historical field" do
    let(:query) { { "fields" => { "discussionThreads" => "words" } } }

    it "sends only the selected field" do
      expect(attributes).to eq("words" => newest.title.split(" "))
    end
  end

  context "when the request selects one component of a merge" do
    let(:query) { { "fields" => { "discussionThreads" => "postedDate" } } }

    it "sends only the selected component" do
      expect(attributes).to eq("postedDate" => "2026-08-03")
    end
  end

  context "when the fieldset uses the current type before its introduction" do
    let(:query) { { "fields" => { "topics" => "words" } } }

    it "corrects the type in the client's vocabulary" do
      expect(error).to include(
        "detail" => "Use discussionThreads, not topics.",
        "source" => {
          "parameter" => "fields[topics]",
        },
      )
    end
  end

  context "when the fieldset uses a later field name" do
    let(:query) { { "fields" => { "discussionThreads" => "title" } } }

    it "corrects the field under the historical type" do
      expect(error).to include(
        "detail" => "Use words, not title.",
        "source" => {
          "parameter" => "fields[discussionThreads]",
        },
      )
    end
  end

  context "when the fieldset has an invalid value" do
    let(:query) { { "fields" => { "discussionThreads" => { "bad" => "value" } } } }

    it "names the historical type in the error" do
      expect(error).to include(
        "detail" => "fields[discussionThreads] must be a list of field names.",
        "source" => {
          "parameter" => "fields[discussionThreads]",
        },
      )
    end
  end

  context "when a current field also has incorrect casing" do
    let(:query) { { "fields" => { "discussionThreads" => "created_at" } } }

    it "suggests a field name valid for the historical type" do
      expect(error).to include(
        "detail" => "Use postedDate, not created_at.",
        "source" => {
          "parameter" => "fields[discussionThreads]",
        },
      )
    end
  end

  context "when the request sorts by a historical attribute" do
    let(:query) { { "sort" => "words" } }

    it "applies the attribute changes before and after the type changes" do
      expect(ids).to eq([oldest.id.to_s, newest.id.to_s, middle.id.to_s])
    end
  end

  context "when the request uses a historical sort name" do
    let(:query) { { "sort" => "bumpedAt" } }

    it "applies the sort change before the type changes" do
      expect(ids).to eq([middle.id.to_s, newest.id.to_s, oldest.id.to_s])
    end
  end

  context "when the request uses a historical filter name" do
    let(:query) { { "filter" => { "name" => newest.title } } }

    it "applies the filter change before the type changes" do
      expect(ids).to contain_exactly(newest.id.to_s)
    end
  end

  context "when the request anchors on a converted historical attribute" do
    let(:query) do
      {
        "sort" => "words",
        "page" => {
          "anchor" => {
            "words" => newest.title.split(" "),
          },
          "beforeSize" => "1",
          "afterSize" => "0",
        },
      }
    end

    it "converts the anchor across the type changes" do
      expect(ids).to eq([oldest.id.to_s, newest.id.to_s])
    end
  end

  context "when the request anchors on merged historical attributes" do
    let(:query) do
      {
        "sort" => "postedDate,postedTime",
        "page" => {
          "anchor" => {
            "postedDate" => "2026-08-02",
            "postedTime" => "00:00:00",
          },
          "beforeSize" => "1",
          "afterSize" => "0",
        },
      }
    end

    it "merges the anchor before the type changes" do
      expect(ids).to eq([oldest.id.to_s, middle.id.to_s])
    end
  end

  context "when the request includes the same author through two paths" do
    let(:query) { { "include" => "user,posts.user" } }
    let(:included_authors) do
      parsed_body
        .fetch("included")
        .select { |resource| resource["type"] == "authors" && resource["id"] == author.id.to_s }
    end

    fab!(:post) { Fabricate(:post, topic: newest, user: newest.user) }

    it "includes one resource for that identity" do
      expect(included_authors).to contain_exactly(
        a_hash_including("type" => "authors", "id" => author.id.to_s),
      )
    end
  end

  context "when an anchor does not match the historical sort" do
    let(:query) do
      {
        "sort" => "words",
        "page" => {
          "anchor" => {
            "postedDate" => "2026-08-02",
            "postedTime" => "00:00:00",
          },
        },
      }
    end

    it "uses historical names in the error" do
      expect(error).to include(
        "detail" => "The anchor is postedDate, but this request sorts by words.",
        "source" => {
          "parameter" => "page[anchor][postedDate]",
        },
      )
    end
  end

  context "when the anchor value cannot be converted" do
    let(:query) { { "sort" => "words", "page" => { "anchor" => { "words" => "invalid" } } } }

    it "uses the historical name in the conversion error" do
      expect(error).to include(
        "detail" => "This version cannot convert the value of words.",
        "source" => {
          "parameter" => "page[anchor]",
        },
      )
    end
  end

  context "when a later change reuses the converter's type name" do
    let(:changes) { [earlier_change, *super(), reuse_change] }
    let(:earlier_change) do
      Class
        .new(JsonApiKit::VersionChange) do
          version "2026-09-01"
          description "Discussion fields change before their values are converted."

          resource :discussion_threads do
            renamed_attribute from: :title_words, to: :words
            renamed_attribute from: :posting_date, to: :posted_date
            renamed_attribute from: :posting_time, to: :posted_time
          end
        end
        .new(__FILE__)
    end
    let(:reuse_change) do
      Class
        .new(JsonApiKit::VersionChange) do
          version "2026-09-05"
          description "Another resource uses the former discussion type."

          renamed_type from: :saved_searches, to: :discussion_threads
        end
        .new(__FILE__)
    end
    let(:query) do
      { "sort" => "titleWords", "page" => { "anchor" => { "titleWords" => "invalid" } } }
    end

    it "reports the field name the client supplied" do
      expect(error).to include(
        "detail" => "This version cannot convert the value of titleWords.",
        "source" => {
          "parameter" => "page[anchor]",
        },
      )
    end

    context "when the converter merges several fields" do
      let(:query) do
        {
          "sort" => "postingDate,postingTime",
          "page" => {
            "anchor" => {
              "postingDate" => "2026-13-45",
              "postingTime" => "00:00:00",
            },
          },
        }
      end

      it "reports every input field in the client's vocabulary" do
        expect(error).to include(
          "detail" => "This version cannot convert the value of postingDate, postingTime.",
          "source" => {
            "parameter" => "page[anchor]",
          },
        )
      end
    end
  end

  context "when the pin follows the first type change" do
    let(:version) { "2026-09-02" }
    let(:query) { { "fields" => { "articles" => "subject" } } }

    it "sends the intermediate type and field name" do
      expect(primary).to include(
        "type" => "articles",
        "attributes" => {
          "subject" => newest.title,
        },
      )
    end
  end

  context "when the pin follows all changes" do
    let(:version) { "2026-09-04" }
    let(:query) { { "fields" => { "topics" => "title,user" }, "include" => "user.groups" } }

    it "sends the current type and field name" do
      expect(primary).to include("type" => "topics", "attributes" => { "title" => newest.title })
    end

    it "sends the current linkage type" do
      expect(primary.dig("relationships", "user", "data")).to eq(
        "type" => "users",
        "id" => author.id.to_s,
      )
    end
  end
end
