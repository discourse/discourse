# frozen_string_literal: true

RSpec.describe JsonApiKit::RelationshipPaths::UnscopedPosition do
  subject(:position) { described_class.new(glossary:) }

  let(:glossary) { JsonApiKit::Glossary.resource(JsonApiKit::Timeline::FIRST_RELEASE) }
  let(:version_change) do
    Class
      .new(JsonApiKit::VersionChange) do
        resource :users do
          renamed_relationship from: :groups, to: :valid_groups
        end
      end
      .new(__FILE__)
  end

  before { allow(JsonApiKit::VersionChanges.core).to receive(:after).and_return([version_change]) }

  describe "#advance_to_member" do
    subject(:step) { position.advance_to_member(declared: "valid_groups") }

    it "applies casing without a resource rename" do
      expect(step.name).to eq("validGroups")
    end

    it "keeps the following position unscoped" do
      expect(step.next_position).to eq(position)
    end
  end
end
