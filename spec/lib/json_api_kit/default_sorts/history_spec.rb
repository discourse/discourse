# frozen_string_literal: true

RSpec.describe JsonApiKit::DefaultSorts::History do
  subject(:history) { described_class.new(resource:, changes:) }

  let(:resource) do
    Class.new(JsonApiKit::Resource) do
      model Topic
      type :topics
      sort :created_at
      sort :title
      default_sort title: :asc
    end
  end
  let(:changes) { [] }

  describe "#ordering" do
    subject(:ordering) { history.ordering }

    it "returns the current default without version changes" do
      expect(ordering).to eq("title" => :asc)
    end

    context "when the default changed after the pin" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:topics) { changed_default_sort from: { created_at: :desc } }
            end
            .new(__FILE__),
        ]
      end

      it "returns the historical default" do
        expect(ordering).to eq("created_at" => :desc)
      end
    end

    context "when the default changed several times" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:topics) { changed_default_sort from: { created_at: :asc } }
            end
            .new(__FILE__),
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:topics) { changed_default_sort from: { created_at: :desc } }
            end
            .new(__FILE__),
        ]
      end

      it "uses the earliest default after the pin" do
        expect(ordering).to eq("created_at" => :asc)
      end
    end

    context "when the historical default is empty" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) { resource(:topics) { changed_default_sort from: {} } }
            .new(__FILE__),
        ]
      end

      it "preserves the empty ordering" do
        expect(ordering).to be_empty
      end
    end

    context "when the same change renames a sort and its resource type" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              renamed_type from: :discussions, to: :topics
              resource :topics do
                renamed_sort from: :posted_at, to: :created_at
                changed_default_sort from: { posted_at: :desc }
              end
            end
            .new(__FILE__),
        ]
      end

      it "uses the current sort name" do
        expect(ordering).to eq("created_at" => :desc)
      end
    end

    context "when sorts and types change before and after the default declaration" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:discussions) { renamed_sort from: :posted_at, to: :published_at }
            end
            .new(__FILE__),
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:discussions) { changed_default_sort from: { published_at: :desc } }
            end
            .new(__FILE__),
          Class
            .new(JsonApiKit::VersionChange) do
              renamed_type from: :discussions, to: :topics
              resource(:topics) { renamed_sort from: :published_at, to: :created_at }
            end
            .new(__FILE__),
        ]
      end

      it "translates from the declaration's version" do
        expect(ordering).to eq("created_at" => :desc)
      end
    end

    context "when an earlier rename reuses the historical default's spelling" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource :topics do
                renamed_sort from: :created_at, to: :title
                renamed_sort from: :posted_at, to: :created_at
              end
            end
            .new(__FILE__),
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:topics) { changed_default_sort from: { created_at: :desc } }
            end
            .new(__FILE__),
        ]
      end

      it "does not apply changes preceding the default declaration" do
        expect(ordering).to eq("created_at" => :desc)
      end
    end

    context "when a later change merges two default sort names" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:topics) do
                changed_default_sort from: { posted_date: :desc, posted_time: :desc }
              end
            end
            .new(__FILE__),
          Class
            .new(JsonApiKit::VersionChange) do
              resource :topics do
                merged_attributes from: %i[posted_date posted_time],
                                  to: :created_at,
                                  up: ->(date, time) { "#{date} #{time}" },
                                  down: ->(time) { time.split(" ") }
              end
            end
            .new(__FILE__),
        ]
      end

      it "uses the merged sort once" do
        expect(ordering).to eq("created_at" => :desc)
      end
    end

    context "when the historical sort is undeclared" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:topics) { changed_default_sort from: { unknown: :asc } }
            end
            .new(__FILE__),
        ]
      end

      it "raises a declaration error" do
        expect { ordering }.to raise_error(
          JsonApiKit::Resource::Sorting::UndeclaredDefault,
          /unknown/,
        )
      end
    end

    context "when the change belongs to another resource" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:users) { changed_default_sort from: { username: :desc } }
            end
            .new(__FILE__),
        ]
      end

      it "uses the resource's current default" do
        expect(ordering).to eq("title" => :asc)
      end
    end

    context "when two resources swap type names" do
      subject(:orderings) do
        resources.to_h { [it.type, described_class.new(resource: it, changes:).ordering] }
      end

      let(:resources) { [resource, Class.new(resource) { type :users }] }
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:topics) { changed_default_sort from: { created_at: :desc } }
              resource(:users) { changed_default_sort from: { title: :desc } }
            end
            .new(__FILE__),
          Class
            .new(JsonApiKit::VersionChange) do
              renamed_type from: :topics, to: :users
              renamed_type from: :users, to: :topics
              resource(:topics) { renamed_sort from: :title, to: :created_at }
              resource(:users) { renamed_sort from: :created_at, to: :title }
            end
            .new(__FILE__),
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:topics) { changed_default_sort from: { title: :asc } }
              resource(:users) { changed_default_sort from: { created_at: :asc } }
            end
            .new(__FILE__),
        ]
      end

      it "keeps the earliest default with each resource" do
        expect(orderings).to eq(
          "topics" => {
            "created_at" => :desc,
          },
          "users" => {
            "title" => :desc,
          },
        )
      end
    end

    context "when another resource acquires an earlier type name" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              resource(:topics) { changed_default_sort from: { title: :desc } }
              resource(:discussions) { changed_default_sort from: { created_at: :desc } }
            end
            .new(__FILE__),
          Class
            .new(JsonApiKit::VersionChange) { renamed_type from: :topics, to: :archives }
            .new(__FILE__),
          Class
            .new(JsonApiKit::VersionChange) { renamed_type from: :discussions, to: :topics }
            .new(__FILE__),
        ]
      end

      it "selects the default belonging to the resource before the rename" do
        expect(ordering).to eq("created_at" => :desc)
      end
    end

    context "when a type rename and a default change share a version change" do
      let(:changes) do
        [
          Class
            .new(JsonApiKit::VersionChange) do
              renamed_type from: :discussions, to: :topics
              resource(:topics) { changed_default_sort from: { created_at: :desc } }
              resource(:users) { changed_default_sort from: { title: :desc } }
            end
            .new(__FILE__),
        ]
      end

      it "looks up the declaration under the type after the rename" do
        expect(ordering).to eq("created_at" => :desc)
      end
    end
  end
end
