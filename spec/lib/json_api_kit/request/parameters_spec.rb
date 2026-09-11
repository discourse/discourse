# frozen_string_literal: true

module JsonApiKitSpec
  class ParametersAuthorResource < JsonApiKit::Resource
    type :users
  end

  class ParametersPostResource < JsonApiKit::Resource
    type :posts
    has_one :last_poster, resource: ParametersAuthorResource
  end

  class ParametersResource < JsonApiKit::Resource
    type :topics
    has_many :ordered_posts, resource: ParametersPostResource
  end

  class ParametersChange < JsonApiKit::VersionChange
    version "2026-09-15"
    description "Two resources rename a field."

    resource :topics do
      renamed_attribute from: :posted_at, to: :created_at
    end

    resource :users do
      renamed_attribute from: :handle, to: :username
    end
  end

  class ParametersMergeChange < JsonApiKit::VersionChange
    version "2026-09-15"
    description "The `posted_date` and `posted_time` attributes of the topics resource become `posted_at`."

    resource :topics do
      merged_attributes from: %i[posted_date posted_time],
                        to: :posted_at,
                        up: ->(date, time) { "#{date} #{time}" },
                        down: ->(posted_at) { posted_at.to_s.split(" ") }
    end
  end

  class ParametersShapeChange < JsonApiKit::VersionChange
    version "2026-09-15"
    description "The `words` attribute of the topics resource becomes `title`, one string."

    resource :topics do
      renamed_attribute from: :words,
                        to: :title,
                        down: ->(title) { title.to_s.split(" ") },
                        up: ->(words) { words.to_a.join(" ") }
    end
  end
end

RSpec.describe JsonApiKit::Request::Parameters do
  subject(:declared_parameters) { request_parameters.to_h }

  let(:request_parameters) do
    described_class.new(parameters, glossary:, resource: JsonApiKitSpec::ParametersResource)
  end
  let(:glossary) { JsonApiKit::Glossary.kit }
  let(:parameters) { { "sort" => "-createdAt" } }

  it "converts the sort into declared names and directions" do
    expect(declared_parameters).to eq("sort" => { "created_at" => :desc })
  end

  context "when the sort holds several names" do
    let(:parameters) { { "sort" => "-createdAt,title" } }

    it "converts every one of them" do
      expect(declared_parameters).to eq("sort" => { "created_at" => :desc, "title" => :asc })
    end
  end

  context "when a sort name has a hyphen" do
    let(:parameters) { { "sort" => "last-posted-at" } }

    it "keeps the hyphen" do
      expect(declared_parameters).to eq("sort" => { "last-posted-at" => :asc })
    end
  end

  context "when the sort is an array" do
    let(:parameters) { { "sort" => %w[createdAt] } }

    it "leaves it to the contract" do
      expect(declared_parameters).to eq("sort" => %w[createdAt])
    end
  end

  context "when the sort is a hash" do
    let(:parameters) { { "sort" => { "createdAt" => :desc } } }

    it "converts the keys only" do
      expect(declared_parameters).to eq("sort" => { "created_at" => :desc })
    end
  end

  context "when the parameters have an include path" do
    let(:parameters) { { "include" => "orderedPosts.lastPoster" } }

    it "converts every segment of the path" do
      expect(declared_parameters).to eq("include" => "ordered_posts.last_poster")
    end

    context "when both relationships have historical names" do
      let(:parameters) { { "include" => "olderPosts.author,olderPosts" } }
      let(:glossary) { JsonApiKit::Glossary.resource(JsonApiKit::Timeline::FIRST_RELEASE) }
      let(:version_change) do
        Class
          .new(JsonApiKit::VersionChange) do
            resource :topics do
              renamed_relationship from: :older_posts, to: :ordered_posts
            end
            resource :posts do
              renamed_relationship from: :author, to: :last_poster
            end
          end
          .new(__FILE__)
      end

      before do
        allow(JsonApiKit::VersionChanges.core).to receive(:after).and_return([version_change])
      end

      it "translates every path against the resource declarations" do
        expect(declared_parameters).to eq("include" => "ordered_posts.last_poster,ordered_posts")
      end

      context "when the paths are an array" do
        let(:parameters) { { "include" => ["olderPosts.author"] } }

        it "preserves the array while translating its paths" do
          expect(declared_parameters).to eq("include" => ["ordered_posts.last_poster"])
        end
      end
    end
  end

  context "when the parameters have a fieldset" do
    let(:parameters) { { "fields" => { "solved-statuses" => "answeredAt" } } }

    it "converts the fieldset into its declared names" do
      expect(declared_parameters).to eq("fields" => { "solved-statuses" => %w[answered_at] })
    end

    context "when the fieldset is empty" do
      let(:parameters) { { "fields" => { "solved-statuses" => "" } } }

      it "returns no name for it" do
        expect(declared_parameters).to eq("fields" => { "solved-statuses" => [] })
      end
    end

    context "when the fieldset is an array" do
      let(:parameters) { { "fields" => { "solved-statuses" => %w[answeredAt] } } }

      it "converts every name" do
        expect(declared_parameters).to eq("fields" => { "solved-statuses" => %w[answered_at] })
      end
    end

    context "when the fieldset is neither a list nor an array" do
      let(:parameters) { { "fields" => { "solved-statuses" => 42 } } }

      it "leaves it to the contract" do
        expect(declared_parameters).to eq("fields" => { "solved-statuses" => 42 })
      end
    end
  end

  context "when a filter is named like a parameter" do
    let(:parameters) { { "filter" => { "sort" => "created_at", "anchor" => "SomeValue" } } }

    it "keeps every filter value" do
      expect(declared_parameters).to eq(
        "filter" => {
          "sort" => "created_at",
          "anchor" => "SomeValue",
        },
      )
    end
  end

  context "when a name is not a member name" do
    let(:parameters) { { "sort" => "created_at" } }

    it "raises with the parameter that holds it" do
      expect { declared_parameters }.to raise_error(
        an_instance_of(JsonApiKit::Glossary::NotAMemberName).and(
          having_attributes(source: { parameter: "sort" }),
        ),
      )
    end

    context "when the name is a key" do
      let(:parameters) { { "page" => { "anchor" => { "created_at" => "2026-08-01" } } } }

      it "raises with the parameter that holds it" do
        expect { declared_parameters }.to raise_error(
          having_attributes(source: { parameter: "page[anchor][created_at]" }),
        )
      end
    end
  end

  context "with a version change" do
    let(:glossary) { JsonApiKit::Glossary.resource(version) }
    let(:version) { JsonApiKit::Timeline::FIRST_RELEASE }
    let(:version_change) { JsonApiKitSpec::ParametersChange.new(__FILE__) }

    before do
      allow(JsonApiKit::VersionChanges.core).to receive(:after).with(version).and_return(
        [version_change],
      )
    end

    context "when a fieldset has a renamed field" do
      let(:parameters) { { "fields" => { "topics" => "postedAt" } } }

      it "converts the field to its current name" do
        expect(declared_parameters).to eq("fields" => { "topics" => %w[created_at] })
      end
    end

    context "when a fieldset of another type has a renamed field" do
      let(:parameters) { { "fields" => { "users" => "handle" } } }

      it "converts the field with the names of that type" do
        expect(declared_parameters).to eq("fields" => { "users" => %w[username] })
      end
    end

    context "when the sort has a renamed field" do
      let(:parameters) { { "sort" => "-postedAt" } }

      it "converts the field to its current name" do
        expect(declared_parameters).to eq("sort" => { "created_at" => :desc })
      end
    end

    context "when the sort has several fields" do
      let(:parameters) { { "sort" => "-postedAt,title" } }

      it "converts every field" do
        expect(declared_parameters).to eq("sort" => { "created_at" => :desc, "title" => :asc })
      end
    end

    context "when the sort has two fields that merge into one" do
      let(:version_change) { JsonApiKitSpec::ParametersMergeChange.new(__FILE__) }
      let(:parameters) { { "sort" => "postedDate,postedTime" } }

      it "converts both to the one field" do
        expect(declared_parameters).to eq("sort" => { "posted_at" => :asc })
      end

      context "when their directions differ" do
        let(:parameters) { { "sort" => "postedDate,-postedTime" } }

        it "raises with the parameter that holds them" do
          expect { declared_parameters }.to raise_error(
            having_attributes(source: { parameter: "sort" }),
          )
        end
      end

      context "when the sort is a hash and their directions differ" do
        let(:parameters) { { "sort" => { "postedDate" => "asc", "postedTime" => "desc" } } }

        it "raises with the parameter that holds them" do
          expect { declared_parameters }.to raise_error(
            having_attributes(source: { parameter: "sort" }),
          )
        end
      end
    end

    context "when a fieldset has several fields" do
      let(:parameters) { { "fields" => { "topics" => "title,postedAt" } } }

      it "converts every field" do
        expect(declared_parameters).to eq("fields" => { "topics" => %w[title created_at] })
      end
    end

    context "when the anchor has a renamed field" do
      let(:parameters) { { "page" => { "anchor" => { "postedAt" => "2026-08-01" } } } }

      it "converts the field to its current name" do
        expect(declared_parameters).to eq(
          "page" => {
            "anchor" => {
              "created_at" => "2026-08-01",
            },
          },
        )
      end
    end

    context "when the anchor has a reshaped field" do
      let(:version_change) { JsonApiKitSpec::ParametersShapeChange.new(__FILE__) }
      let(:parameters) { { "page" => { "anchor" => { "words" => %w[Anchors and pages] } } } }

      it "converts the field to its current name and shape" do
        expect(declared_parameters).to eq(
          "page" => {
            "anchor" => {
              "title" => "Anchors and pages",
            },
          },
        )
      end
    end

    context "when a filter has the name of a renamed field" do
      let(:parameters) { { "filter" => { "postedAt" => "2026-08-01" } } }

      it "converts the case of the filter name only" do
        expect(declared_parameters).to eq("filter" => { "posted_at" => "2026-08-01" })
      end
    end
  end

  context "when a name has a newline" do
    let(:parameters) { { "sort" => "createdAt\n" } }

    it "converts the case and keeps the newline for the contract" do
      expect(declared_parameters).to eq("sort" => { "created_at\n" => :asc })
    end
  end

  context "when the parameters have a filter" do
    let(:parameters) { { "filter" => { "postCount" => "SomeTopic Title" } } }

    it "converts the filter name only" do
      expect(declared_parameters).to eq("filter" => { "post_count" => "SomeTopic Title" })
    end
  end

  context "when the parameters have page members" do
    let(:parameters) { { "page" => { "beforeSize" => "1", "after" => "WyJhQiJd" } } }

    it "converts the member names only" do
      expect(declared_parameters).to eq("page" => { "before_size" => "1", "after" => "WyJhQiJd" })
    end
  end

  context "when the parameters anchor on an attribute" do
    let(:parameters) { { "page" => { "anchor" => { "createdAt" => "2026-08-01" } } } }

    it "converts the anchor name only" do
      expect(declared_parameters).to eq("page" => { "anchor" => { "created_at" => "2026-08-01" } })
    end
  end

  context "when the parameters anchor on a computed position" do
    let(:parameters) { { "page" => { "anchor" => "withoutReplies" } } }

    it "converts the anchor name" do
      expect(declared_parameters).to eq("page" => { "anchor" => "without_replies" })
    end
  end

  context "when a type changes after a field name" do
    let(:glossary) { JsonApiKit::Glossary.resource(JsonApiKit::Timeline::FIRST_RELEASE) }
    let(:field_change) do
      Class
        .new(JsonApiKit::VersionChange) do
          resource :discussion_threads do
            renamed_attribute from: :heading, to: :title
            renamed_filter from: :label, to: :title
          end
        end
        .new(__FILE__)
    end
    let(:type_change) do
      Class
        .new(JsonApiKit::VersionChange) { renamed_type from: :discussion_threads, to: :topics }
        .new(__FILE__)
    end

    before do
      allow(JsonApiKit::VersionChanges.core).to receive(:after).and_return(
        [field_change, type_change],
      )
    end

    context "when the request supplies a fieldset" do
      let(:parameters) { { "fields" => { "discussionThreads" => "heading" } } }

      it "translates the type and field together" do
        expect(declared_parameters).to eq("fields" => { "topics" => ["title"] })
      end
    end

    context "when the fieldset is empty" do
      let(:parameters) { { "fields" => { "discussionThreads" => "" } } }

      it "translates the type without a field name" do
        expect(declared_parameters).to eq("fields" => { "topics" => [] })
      end
    end

    context "when the fieldset value is invalid" do
      let(:parameters) { { "fields" => { "discussionThreads" => 42 } } }

      it "translates the type for the contract" do
        expect(declared_parameters).to eq("fields" => { "topics" => 42 })
      end
    end

    context "when the request supplies names without a type" do
      let(:parameters) do
        {
          "sort" => "heading",
          "filter" => {
            "label" => "A",
          },
          "page" => {
            "anchor" => {
              "heading" => "A",
            },
          },
        }
      end

      it "derives the historical type before translating names" do
        expect(declared_parameters).to eq(
          "sort" => {
            "title" => :asc,
          },
          "filter" => {
            "title" => "A",
          },
          "page" => {
            "anchor" => {
              "title" => "A",
            },
          },
        )
      end
    end
  end

  describe "#fieldsets" do
    subject(:fieldsets) { request_parameters.fieldsets }

    let(:parameters) { { "fields" => { "topics" => "postedDate" } } }

    it "returns the fieldsets under the names the client sent" do
      expect(fieldsets.keep("topics", "postedDate" => "2026-08-01", "title" => "A")).to eq(
        "postedDate" => "2026-08-01",
      )
    end
  end
end
