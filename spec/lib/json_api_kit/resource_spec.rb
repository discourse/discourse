# frozen_string_literal: true

# Resources are named after what they expose, so these need names — and a namespace, since a
# resource resolves its model inside its own.
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

  let(:topic_resource) do
    Class.new(described_class) do
      model Topic
      sort :created_at
      sort :ran_at, column: :last_posted_at
      default_sort ran_at: :desc
      unique_by :title, :id
      filter :title
    end
  end

  describe ".model" do
    subject(:model) { resource.model }

    it "infers the model in the resource's own namespace" do
      expect(model).to eq(SpecBlog::Post)
    end

    context "when nothing is named after the resource" do
      subject(:resource) { SpecBlog::UnbackedResource }

      it "asks for an explicit declaration" do
        expect { model }.to raise_error(described_class::MissingDeclaration, /Unbacked/)
      end
    end

    context "when the resource has no name to infer from" do
      subject(:resource) { Class.new(described_class) }

      it "asks for an explicit declaration" do
        expect { model }.to raise_error(described_class::MissingDeclaration)
      end
    end

    context "when the model is declared" do
      subject(:resource) { Class.new(described_class) { model Category } }

      it "returns the declared model" do
        expect(model).to eq(Category)
      end
    end

    context "when the model is declared after the resource has been read" do
      subject(:resource) { Class.new(described_class) { model Category } }

      before do
        resource.model
        resource.model(Topic)
      end

      it "answers with the one declared last" do
        expect(model).to eq(Topic)
      end
    end

    context "when the model is declared by name" do
      subject(:resource) { Class.new(described_class) { model :category } }

      it "resolves the name to the model" do
        expect(model).to eq(Category)
      end
    end

    context "when the declared name is a path" do
      subject(:resource) { Class.new(described_class) { model "spec_blog/post" } }

      it "resolves it to the namespaced model" do
        expect(model).to eq(SpecBlog::Post)
      end
    end

    context "when the declared name matches no model" do
      subject(:resource) { Class.new(described_class) { model :nowhere_to_be_found } }

      it "reports the name it could not find" do
        expect { model }.to raise_error(described_class::MissingDeclaration, /NowhereToBeFound/)
      end
    end

    context "with a resource inheriting from another" do
      subject(:resource) { Class.new(parent) }

      let(:parent) { Class.new(described_class) { model Category } }

      it "inherits the declared model" do
        expect(model).to eq(Category)
      end

      context "when it declares a model of its own" do
        before { resource.model(Topic) }

        it "leaves the parent's model alone" do
          expect(parent.model).to eq(Category)
        end
      end
    end
  end

  describe ".type" do
    subject(:type) { resource.type }

    it "infers a plural type from the resource name, without the namespace" do
      expect(type).to eq("posts")
    end

    context "when the resource is named after several words" do
      subject(:resource) { SpecBlog::CommentThreadResource }

      it "spells a multi-word type with underscores" do
        expect(type).to eq("comment_threads")
      end
    end

    context "when the type is declared" do
      subject(:resource) { Class.new(described_class) { type :threads } }

      it "returns the declared type as a string" do
        expect(type).to eq("threads")
      end
    end

    context "when the resource has no name to infer from" do
      subject(:resource) { Class.new(described_class) }

      it "asks for an explicit declaration" do
        expect { type }.to raise_error(described_class::MissingDeclaration)
      end
    end

    context "with a resource inheriting from another" do
      subject(:resource) { Class.new(parent) }

      let(:parent) { Class.new(described_class) { type :threads } }

      it "inherits the declared type" do
        expect(type).to eq("threads")
      end

      context "when it declares a type of its own" do
        before { resource.type(:posts) }

        it "leaves the parent's type alone" do
          expect(parent.type).to eq("threads")
        end
      end
    end
  end

  describe ".sort" do
    subject(:keyset) { topic_resource.sorts.keyset(created_at: :desc) }

    it "declares an order a request may ask for" do
      expect(keyset.leading.name).to eq(:created_at)
    end
  end

  describe ".sorts" do
    subject(:child) { Class.new(topic_resource) }

    context "when a sort is declared after the resource has been read" do
      before do
        topic_resource.sorts
        topic_resource.sort(:closed)
      end

      it "offers it all the same, a plugin declaring long after the class body ran" do
        expect(topic_resource.sorts.fetch("closed").name).to eq("closed")
      end
    end

    before { child.sort(:title) }

    it "inherits the sorts declared above it" do
      expect(child.sorts.fetch("created_at").name).to eq("created_at")
    end

    it "leaves the resource it inherits from alone when it declares its own" do
      expect { topic_resource.sorts.fetch("title") }.to raise_error(
        JsonApiKit::Declarations::Sorts::Unsupported,
      )
    end
  end

  describe ".default_sort" do
    subject(:keyset) { topic_resource.sorts.keyset({}) }

    it "declares what a listing is ordered by when the request names nothing" do
      expect(keyset.keys.map(&:name)).to eq(%i[last_posted_at title id])
    end
  end

  describe ".unique_by" do
    subject(:keyset) { topic_resource.sorts.keyset(created_at: :desc) }

    it "declares the columns that leave no two rows sharing a place" do
      expect(keyset.keys.map(&:name)).to eq(%i[created_at title id])
    end
  end

  describe ".filter" do
    subject(:filtered) { topic_resource.filters.apply(Topic.all, title: kept.title) }

    fab!(:kept) { Fabricate(:topic, title: "The rows a filter keeps") }
    fab!(:dropped) { Fabricate(:topic, title: "The rows it leaves behind") }

    it "declares a condition a request may ask for" do
      expect(filtered.map(&:id)).to contain_exactly(kept.id)
    end

    context "when it is declared after the resource has been read" do
      before do
        topic_resource.filters
        topic_resource.filter(:closed)
      end

      it "offers it all the same, a plugin declaring long after the class body ran" do
        expect(topic_resource.filters.fetch("closed").name).to eq("closed")
      end
    end
  end

  describe ".scope_for" do
    subject(:exposed) { topic_resource.scope_for(Guardian.new) }

    it "is every row of the model, a resource declaring no scope holding nothing back" do
      expect(exposed.to_sql).to eq(Topic.all.to_sql)
    end

    context "with a scope declared" do
      subject(:exposed) { closed_topics.scope_for(Guardian.new) }

      let(:closed_topics) do
        Class.new(described_class) do
          model Topic
          scope { |guardian| Topic.where(closed: true) }
        end
      end

      it "is the rows that scope allows" do
        expect(exposed.to_sql).to eq(Topic.where(closed: true).to_sql)
      end
    end
  end

  describe ".all" do
    subject(:listing) { topic_resource.all({ sort: { created_at: :asc } }, guardian: Guardian.new) }

    fab!(:topic) { Fabricate(:topic, title: "A listing read from a resource") }

    it "is a listing of the resource, read for whoever is asking" do
      expect(listing.records).to eq([topic])
    end
  end

  describe ".order" do
    subject(:order) { topic_resource.order(ran_at: :desc) }

    it "reads the listing in the bands its keyset splits into" do
      expect(order.segments.size).to eq(2)
    end
  end
end
