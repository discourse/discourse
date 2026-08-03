# frozen_string_literal: true

module SpecBlog
  Post = Class.new

  class PostResource < JsonApiKit::Resource
  end

  class CommentThreadResource < JsonApiKit::Resource
  end

  class UnbackedResource < JsonApiKit::Resource
  end
end

RSpec.describe JsonApiKit::Resource do
  subject(:resource) { SpecBlog::PostResource }

  let(:guardian) { Guardian.new }
  let(:group_resource) do
    Class.new(described_class) do
      model Group
      type :groups
    end
  end
  let(:user_resource) do
    related = group_resource

    Class.new(described_class) do
      model User
      type :users
      has_many :groups, resource: related
    end
  end
  let(:topic_resource) do
    related = user_resource

    Class.new(described_class) do
      model Topic
      type :topics
      sort :created_at
      sort :ran_at, column: :last_posted_at
      default_sort ran_at: :desc
      unique_by :title, :id
      filter :title
      page default: 2, max: 10
      attribute :title
      has_one :user, resource: related
      has_many :posts, resource: related
      includes "user.groups"
    end
  end

  describe ".model" do
    subject(:model) { resource.model }

    it "infers the model in the resource's own namespace" do
      expect(model).to eq(SpecBlog::Post)
    end

    context "when no model matches the resource name" do
      subject(:resource) { SpecBlog::UnbackedResource }

      it "asks for a declaration" do
        expect { model }.to raise_error(described_class::MissingDeclaration, /Unbacked/)
      end
    end

    context "when the resource has no name to infer from" do
      subject(:resource) { Class.new(described_class) }

      it "asks for a declaration" do
        expect { model }.to raise_error(described_class::MissingDeclaration)
      end
    end

    context "when the resource declares a model" do
      subject(:resource) { Class.new(described_class) { model Category } }

      it "returns the model it declares" do
        expect(model).to eq(Category)
      end
    end

    context "when the resource declares another model after a reading" do
      subject(:resource) { Class.new(described_class) { model Category } }

      before do
        resource.model
        resource.model(Topic)
      end

      it "returns the new model" do
        expect(model).to eq(Topic)
      end
    end

    context "when the resource declares the model by name" do
      subject(:resource) { Class.new(described_class) { model :category } }

      it "returns the model that name matches" do
        expect(model).to eq(Category)
      end
    end

    context "when that name is a path" do
      subject(:resource) { Class.new(described_class) { model "spec_blog/post" } }

      it "returns the model in that namespace" do
        expect(model).to eq(SpecBlog::Post)
      end
    end

    context "when that name matches no model" do
      subject(:resource) { Class.new(described_class) { model :nowhere_to_be_found } }

      it "refuses the model name" do
        expect { model }.to raise_error(described_class::MissingDeclaration, /NowhereToBeFound/)
      end
    end

    context "when a resource inherits from another" do
      subject(:resource) { Class.new(parent) }

      let(:parent) { Class.new(described_class) { model Category } }

      it "returns the model declared above it" do
        expect(model).to eq(Category)
      end

      context "when it declares a model of its own" do
        before { resource.model(Topic) }

        it "leaves the model above it alone" do
          expect(parent.model).to eq(Category)
        end
      end
    end
  end

  describe ".type" do
    subject(:type) { resource.type }

    it "infers a plural type from the resource name without the namespace" do
      expect(type).to eq("posts")
    end

    context "when the resource name holds several words" do
      subject(:resource) { SpecBlog::CommentThreadResource }

      it "spells the type with underscores" do
        expect(type).to eq("comment_threads")
      end
    end

    context "when the resource declares a type" do
      subject(:resource) { Class.new(described_class) { type :threads } }

      it "returns that type as a string" do
        expect(type).to eq("threads")
      end
    end

    context "when the resource has no name to infer from" do
      subject(:resource) { Class.new(described_class) }

      it "asks for a declaration" do
        expect { type }.to raise_error(described_class::MissingDeclaration)
      end
    end

    context "when a resource inherits from another" do
      subject(:resource) { Class.new(parent) }

      let(:parent) { Class.new(described_class) { type :threads } }

      it "returns the type declared above it" do
        expect(type).to eq("threads")
      end

      context "when it declares a type of its own" do
        before { resource.type(:posts) }

        it "leaves the type above it alone" do
          expect(parent.type).to eq("threads")
        end
      end
    end
  end

  describe ".schema" do
    it "returns a schema for the model it exposes" do
      expect(topic_resource.schema.model).to eq(Topic)
    end
  end

  describe ".sort" do
    it "lets a request order the listing by the name it declares" do
      expect(topic_resource.order("created_at" => :desc).leading.name).to eq(:created_at)
    end
  end

  describe ".sort_names" do
    it "returns the name of every sort the resource declares" do
      expect(topic_resource.sort_names).to eq(%w[created_at ran_at])
    end

    context "when the resource declares one more after a reading" do
      before do
        topic_resource.sort_names
        topic_resource.sort(:closed)
      end

      it "returns the new name too" do
        expect(topic_resource.sort_names).to include("closed")
      end
    end

    context "when a resource inherits from another" do
      subject(:child) { Class.new(topic_resource) }

      before { child.sort(:title) }

      it "inherits the sorts of its parent" do
        expect(child.sort_names).to include("created_at")
      end

      it "leaves the resource it inherits from alone" do
        expect(topic_resource.sort_names).not_to include("title")
      end
    end
  end

  describe ".default_sort" do
    it "reads a listing in the order the resource declares" do
      expect(topic_resource.order.leading.name).to eq(:last_posted_at)
    end

    context "when the resource declares no such sort" do
      it "refuses the declaration" do
        expect {
          Class.new(described_class) do
            model Topic
            default_sort creatd_at: :asc
          end
        }.to raise_error(JsonApiKit::Resource::Sorting::UndeclaredDefault, /creatd_at/)
      end
    end
  end

  describe ".unique_by" do
    it "breaks ties by those columns in that sequence" do
      expect(topic_resource.order("created_at" => :desc).columns).to eq(%i[created_at title id])
    end
  end

  describe ".filter" do
    subject(:kept_ids) do
      topic_resource.apply_filters(Topic.all, "title" => kept_topic.title).map(&:id)
    end

    fab!(:kept_topic) { Fabricate(:topic, title: "The rows a filter keeps") }
    fab!(:dropped_topic) { Fabricate(:topic, title: "The rows it leaves behind") }

    it "lets a request narrow the listing by the name it declares" do
      expect(kept_ids).to contain_exactly(kept_topic.id)
    end

    context "when the resource declares one more after a reading" do
      subject(:kept_ids) { topic_resource.apply_filters(Topic.all, "closed" => false).map(&:id) }

      before do
        topic_resource.apply_filters(Topic.all)
        topic_resource.filter(:closed)
      end

      it "narrows by the new filter too" do
        expect(kept_ids).to include(kept_topic.id)
      end
    end
  end

  describe ".attribute" do
    subject(:attribute_values) { topic_resource.fields.attributes.values_for(topic) }

    fab!(:topic) { Fabricate(:topic, title: "A field a resource renders") }

    it "renders the field the resource declares" do
      expect(attribute_values).to eq("title" => topic.title)
    end

    context "when the resource declares one more after a reading" do
      before do
        topic_resource.fields.attributes
        topic_resource.attribute(:closed)
      end

      it "renders the new field too" do
        expect(attribute_values).to include("closed")
      end
    end
  end

  describe ".has_one" do
    subject(:user_relationships) { topic_resource.fields.relationships.pick(%w[user]) }

    it "relates the resource to one record of another" do
      expect(user_relationships.first.resource).to eq(user_resource)
    end

    it "lets a request include the relationship" do
      expect(topic_resource.allow(JsonApiKit::Paths.new(%w[user])).map(&:to_s)).to eq(%w[user])
    end

    context "when the resource declares one more after a reading" do
      subject(:category_relationships) { topic_resource.fields.relationships.pick(%w[category]) }

      before do
        topic_resource.fields
        topic_resource.has_one(:category, resource: user_resource)
      end

      it "relates to the new resource too" do
        expect(category_relationships.map(&:name)).to eq(%w[category])
      end
    end
  end

  describe ".has_many" do
    subject(:posts_relationships) { topic_resource.fields.relationships.pick(%w[posts]) }

    it "relates the resource to many records of another" do
      expect(posts_relationships.first).to be_a(JsonApiKit::Declarations::Relationship::ToMany)
    end
  end

  describe ".resolves?" do
    let(:relationships) { instance_spy(JsonApiKit::Declarations::Relationships) }
    let(:path) { JsonApiKit::Path.for("user") }

    before do
      allow(JsonApiKit::Declarations::Relationships).to receive(:new).and_return(relationships)
    end

    it "asks its relationships to resolve the path" do
      topic_resource.resolves?(path)

      expect(relationships).to have_received(:resolves?).with(path)
    end
  end

  describe ".includes" do
    subject(:allowed_paths) { topic_resource.allow(JsonApiKit::Paths.new(%w[user.groups])) }

    it "lets a request read a path through a relationship" do
      expect(allowed_paths.map(&:to_s)).to eq(%w[user.groups])
    end

    context "when the path reads a relationship no resource declares" do
      before { topic_resource.includes("user.badges") }

      it "refuses to read the resource" do
        expect { allowed_paths }.to raise_error(
          JsonApiKit::Declarations::IncludePaths::Unresolved,
          /user\.badges/,
        )
      end
    end

    context "when a resource inherits from another" do
      subject(:child) { Class.new(topic_resource) }

      before { child.includes("posts.groups") }

      it "reads the paths declared above it" do
        expect(child.allow(JsonApiKit::Paths.new(%w[user.groups])).map(&:to_s)).to eq(
          %w[user.groups],
        )
      end

      it "leaves the resource it inherits from alone" do
        expect { topic_resource.allow(JsonApiKit::Paths.new(%w[posts.groups])) }.to raise_error(
          KeyError,
        )
      end
    end
  end

  describe ".page" do
    it "returns the size the resource declares" do
      expect(topic_resource.page_limits.size(nil)).to eq(2)
    end

    context "when the resource declares each bound in its own call" do
      subject(:limits) do
        Class
          .new(described_class) do
            model Topic
            page default: 20
            page max: 50
          end
          .page_limits
      end

      it "keeps the size the earlier call declares" do
        expect(limits.size(nil)).to eq(20)
      end

      it "keeps the maximum the later call declares" do
        expect(limits.max).to eq(50)
      end
    end

    context "when the default is larger than the maximum" do
      it "refuses the declaration" do
        expect {
          Class.new(described_class) do
            model Topic
            page default: 200
            page max: 50
          end
        }.to raise_error(JsonApiKit::Page::Limits::OutOfRange)
      end
    end
  end

  describe ".page_size" do
    it "returns the size a page reads at" do
      expect(topic_resource.page_size).to eq(2)
    end
  end

  describe ".anchored_by?" do
    subject(:resource) { Class.new(topic_resource) { anchor :created_at } }

    let(:ordering) { { "created_at" => :asc } }

    it { is_expected.to be_anchored_by(anchor_name: :created_at, ordering:) }

    context "when the order does not read by that anchor" do
      let(:ordering) { { "ran_at" => :desc } }

      it { is_expected.not_to be_anchored_by(anchor_name: :created_at, ordering:) }
    end

    context "when the resource declares no anchor by that name" do
      it { is_expected.to be_anchored_by(anchor_name: :first_unread) }
    end
  end

  describe ".scope_for" do
    subject(:exposed_scope) { topic_resource.scope_for(guardian) }

    it "returns every row of the model" do
      expect(exposed_scope.to_sql).to eq(Topic.all.to_sql)
    end

    context "when the resource declares a scope" do
      subject(:exposed_scope) { closed_topics.scope_for(guardian) }

      let(:closed_topics) do
        Class.new(described_class) do
          model Topic
          scope { |guardian| Topic.where(closed: true) }
        end
      end

      it "returns the rows that scope allows" do
        expect(exposed_scope.to_sql).to eq(Topic.where(closed: true).to_sql)
      end
    end
  end

  describe ".all" do
    before { allow(JsonApiKit::Query::Collection).to receive(:new) }

    it "reads a listing for the request a caller sends" do
      topic_resource.all({ sort: { created_at: :asc } }, guardian:)

      expect(JsonApiKit::Query::Collection).to have_received(:new).with(
        topic_resource,
        an_object_having_attributes(ordering: { "created_at" => :asc }, guardian:),
        scoped_to: nil,
      )
    end
  end

  describe ".paged_from?" do
    fab!(:topic) { Fabricate(:topic, title: "A page read from a cursor") }

    let(:ordering) { { "created_at" => :asc } }
    let(:cursor) { topic_resource.order(ordering).first.position_of(topic).to_cursor }

    it "accepts a cursor from the order it declares" do
      expect(topic_resource).to be_paged_from(cursor, ordering:)
    end
  end

  describe ".order" do
    it "splits the order in two where a column allows null" do
      expect(topic_resource.order("ran_at" => :desc).segments.size).to eq(2)
    end

    context "when no column of the order allows null" do
      it "reads the listing in one segment" do
        expect(topic_resource.order("created_at" => :desc).segments.size).to eq(1)
      end
    end
  end
end
