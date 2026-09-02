# frozen_string_literal: true

class SpecOrphanResource < JsonApiKit::Resource
end

class SpecImpostorResource
end

class SpecTwinResource < JsonApiKit::Resource
end

module SpecLookup
  class UserResource < JsonApiKit::Resource
  end

  class SpecTwinResource < JsonApiKit::Resource
  end

  class QueryResource < JsonApiKit::Resource
  end
end

RSpec.describe JsonApiKit::ResourceLookup do
  subject(:found) { described_class.resource(declaration, within: SpecLookup::QueryResource) }

  let(:declaration) { :user }

  context "when the resource is in the same namespace" do
    it { is_expected.to eq(SpecLookup::UserResource) }
  end

  context "with a plural name" do
    let(:declaration) { :users }

    it { is_expected.to eq(SpecLookup::UserResource) }
  end

  context "when the resource is at the root" do
    let(:declaration) { :spec_orphan }

    it { is_expected.to eq(SpecOrphanResource) }
  end

  context "when the resource is in both" do
    let(:declaration) { :spec_twin }

    it "prefers the same namespace" do
      expect(found).to eq(SpecLookup::SpecTwinResource)
    end
  end

  context "when the resource doesn’t exist" do
    let(:declaration) { :author }

    it "raises a missing-resource error with the attempted names" do
      expect { found }.to raise_error(
        described_class::MissingResource,
        "SpecLookup::QueryResource: no resource is named author, " \
          "tried SpecLookup::AuthorResource, AuthorResource",
      )
    end
  end

  context "with a resource class" do
    let(:declaration) { SpecOrphanResource }

    it { is_expected.to eq(SpecOrphanResource) }
  end

  context "with another kind of class" do
    let(:declaration) { Topic }

    it "rejects non-resource classes" do
      expect { found }.to raise_error(
        described_class::UnsupportedResource,
        "SpecLookup::QueryResource: Topic is not a JSON:API resource",
      )
    end
  end

  context "with a name matching another kind of class" do
    let(:declaration) { :spec_impostor }

    it "rejects names resolving to non-resource classes" do
      expect { found }.to raise_error(
        described_class::UnsupportedResource,
        "SpecLookup::QueryResource: SpecImpostorResource is not a JSON:API resource",
      )
    end
  end
end
