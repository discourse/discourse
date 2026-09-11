# frozen_string_literal: true

module JsonApiKitSpec
  class PathGroupsResource < JsonApiKit::Resource
    type :groups
  end

  class PathUsersResource < JsonApiKit::Resource
    type :users
    has_many :valid_groups, resource: PathGroupsResource
  end

  class PathTopicsResource < JsonApiKit::Resource
    type :topics
    has_one :writer, resource: PathUsersResource
  end

  PathGroupsResource.has_many(:members, resource: PathUsersResource)
end

RSpec.describe JsonApiKit::RelationshipPaths::Position do
  subject(:position) do
    described_class.new(resource: JsonApiKitSpec::PathTopicsResource, glossary:)
  end

  let(:glossary) { JsonApiKit::Glossary.resource(JsonApiKit::Timeline::FIRST_RELEASE) }
  let(:version_change) do
    Class
      .new(JsonApiKit::VersionChange) do
        resource :topics do
          renamed_relationship from: :author, to: :writer
        end
        resource :users do
          renamed_relationship from: :groups, to: :valid_groups
        end
      end
      .new(__FILE__)
  end

  before { allow(JsonApiKit::VersionChanges.core).to receive(:after).and_return([version_change]) }

  describe "#advance_to_declared" do
    subject(:step) { position.advance_to_declared(member:) }

    let(:member) { "author" }

    it "returns the declared name at the current resource" do
      expect(step.name).to eq("writer")
    end

    it "returns a new position at the target resource" do
      expect(step.next_position).to eq(
        described_class.new(resource: JsonApiKitSpec::PathUsersResource, glossary:),
      )
    end

    it "preserves the starting resource" do
      step
      expect(position.resource).to eq(JsonApiKitSpec::PathTopicsResource)
    end

    context "when the position follows the first relationship" do
      let(:member) { "groups" }
      let(:position) { super().advance_to_declared(member: "author").next_position }

      it "translates the next name in the target resource" do
        expect(step.name).to eq("valid_groups")
      end
    end
  end

  describe "#advance_to_member" do
    subject(:step) { position.advance_to_member(declared:) }

    let(:declared) { "writer" }

    it "translates the name using the owning resource" do
      expect(step.name).to eq("author")
    end

    it "returns a new position at the target resource" do
      expect(step.next_position).to eq(
        described_class.new(resource: JsonApiKitSpec::PathUsersResource, glossary:),
      )
    end

    it "preserves the starting resource" do
      step
      expect(position.resource).to eq(JsonApiKitSpec::PathTopicsResource)
    end

    context "when the position follows the first relationship" do
      let(:declared) { "valid_groups" }
      let(:position) { super().advance_to_member(declared: "writer").next_position }

      it "translates the next name in the target resource" do
        expect(step.name).to eq("groups")
      end
    end

    context "when the relationship cannot be resolved" do
      let(:declared) { "missing_groups" }

      it "formats the unresolved name as a member" do
        expect(step.name).to eq("missingGroups")
      end

      it "continues from an unscoped position" do
        expect(step.next_position).to eq(
          JsonApiKit::RelationshipPaths::UnscopedPosition.new(glossary:),
        )
      end
    end
  end
end

RSpec.describe JsonApiKit::RelationshipPaths do
  subject(:paths) { described_class.new(resource: JsonApiKitSpec::PathTopicsResource, glossary:) }

  let(:glossary) { JsonApiKit::Glossary.resource(JsonApiKit::Timeline::FIRST_RELEASE) }
  let(:version_change) do
    Class
      .new(JsonApiKit::VersionChange) do
        renamed_type from: :articles, to: :topics
        renamed_type from: :people, to: :users
        resource :topics do
          renamed_relationship from: :author, to: :writer
        end
        resource :users do
          renamed_relationship from: :groups, to: :valid_groups
        end
      end
      .new(__FILE__)
  end

  before { allow(JsonApiKit::VersionChanges.core).to receive(:after).and_return([version_change]) }

  describe "#declared_path" do
    subject(:declared_path) { paths.declared_path(path) }

    let(:path) { "author.groups" }

    it "translates each segment in its owning resource" do
      expect(declared_path).to eq("writer.valid_groups")
    end

    context "when the path is empty" do
      let(:path) { "" }

      it "returns an empty path" do
        expect(declared_path).to eq("")
      end
    end

    context "when the path returns to an earlier resource" do
      let(:path) { "author.groups.members.groups" }

      it "uses that resource's vocabulary again" do
        expect(declared_path).to eq("writer.valid_groups.members.valid_groups")
      end
    end

    context "when a cyclic path has many segments" do
      let(:path) { "author.#{Array.new(1500, "groups.members").join(".")}" }
      let(:expected_path) { "writer.#{Array.new(1500, "valid_groups.members").join(".")}" }

      it "translates the complete path without exhausting the stack" do
        expect(declared_path).to eq(expected_path)
      end
    end

    context "when the first segment does not exist" do
      let(:path) { "unknownAuthor.groups" }

      it "reports the original path" do
        expect { declared_path }.to raise_error(
          described_class::UnknownPath,
          /unknownAuthor.groups/,
        )
      end
    end

    context "when a later segment does not exist" do
      let(:path) { "author.unknownGroups.members" }

      it "preserves the client spelling of every segment" do
        expect { declared_path }.to raise_error(
          described_class::UnknownPath,
          "There is no relationship path named author.unknownGroups.members.",
        )
      end
    end

    context "when a segment belongs to another version" do
      let(:path) { "author.validGroups" }

      it "suggests the historical name of that segment" do
        expect { declared_path }.to raise_error(
          JsonApiKit::Glossary::NotAMemberName,
          "Use groups, not validGroups.",
        )
      end
    end

    context "when the path contains an empty segment" do
      let(:path) { "author..groups" }

      it "rejects the path" do
        expect { declared_path }.to raise_error(described_class::UnknownPath)
      end
    end

    context "when the path ends with a separator" do
      let(:path) { "author." }

      it "rejects the path" do
        expect { declared_path }.to raise_error(described_class::UnknownPath)
      end
    end
  end

  describe "#member_path" do
    subject(:member_path) { paths.member_path(path) }

    let(:path) { "writer.valid_groups" }

    it "translates the current path into the client's vocabulary" do
      expect(member_path).to eq("author.groups")
    end

    context "when the path is empty" do
      let(:path) { "" }

      it "returns an empty path" do
        expect(member_path).to eq("")
      end
    end

    context "when a cyclic path has many segments" do
      let(:path) { "writer.#{Array.new(1500, "valid_groups.members").join(".")}" }
      let(:expected_path) { "author.#{Array.new(1500, "groups.members").join(".")}" }

      it "translates the complete path without exhausting the stack" do
        expect(member_path).to eq(expected_path)
      end
    end

    context "when a segment cannot be resolved" do
      let(:path) { "writer.missing_groups.last_member" }

      before { allow(glossary).to receive(:unscoped_member).and_call_original }

      it "translates the known prefix and formats the unknown suffix" do
        expect(member_path).to eq("author.missingGroups.lastMember")
      end

      it "formats the last segment through the request glossary" do
        member_path
        expect(glossary).to have_received(:unscoped_member).with(declared: "last_member")
      end

      context "when a later segment matches a renamed relationship" do
        let(:path) { "writer.missing_groups.valid_groups" }

        it "formats the suffix without applying resource-specific renames" do
          expect(member_path).to eq("author.missingGroups.validGroups")
        end
      end
    end

    context "when the glossary has no version changes" do
      let(:glossary) { JsonApiKit::Glossary.kit }

      it "converts current names to camel case" do
        expect(member_path).to eq("writer.validGroups")
      end
    end
  end
end
