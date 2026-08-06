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
end
