# frozen_string_literal: true

RSpec.describe JsonApiKit::Glossary do
  subject(:glossary) { described_class.resource(JsonApiKit::Timeline::FIRST_RELEASE) }

  let(:type) { "discussion_threads" }
  let(:earlier_change) do
    Class
      .new(JsonApiKit::VersionChange) do
        resource :articles do
          renamed_relationship from: :original_author, to: :author
        end
      end
      .new(__FILE__)
  end
  let(:type_change) do
    Class
      .new(JsonApiKit::VersionChange) { renamed_type from: :articles, to: :discussion_threads }
      .new(__FILE__)
  end
  let(:later_change) do
    Class
      .new(JsonApiKit::VersionChange) do
        resource :discussion_threads do
          renamed_relationship from: :author, to: :writer
        end
      end
      .new(__FILE__)
  end

  before do
    allow(JsonApiKit::VersionChanges.core).to receive(:after).and_return(
      [earlier_change, type_change, later_change],
    )
  end

  describe "#declared_relationship" do
    subject(:declared_name) { glossary.declared_relationship(member:, type:) }

    let(:member) { "originalAuthor" }

    it "uses the historical type to translate the relationship" do
      expect(declared_name).to eq("writer")
    end

    context "when the client supplies a newer name" do
      let(:member) { "writer" }

      it "suggests the name from the client's version" do
        expect { declared_name }.to raise_error(
          described_class::NotAMemberName,
          "Use originalAuthor, not writer.",
        )
      end
    end

    context "when the glossary has no version changes" do
      let(:glossary) { described_class.kit }

      it "converts the member name into declared casing" do
        expect(declared_name).to eq("original_author")
      end
    end
  end

  describe "#member_relationship" do
    subject(:member_name) { glossary.member_relationship(declared: "writer", type:) }

    it "translates the relationship across field and type changes" do
      expect(member_name).to eq("originalAuthor")
    end

    context "when the relationship belongs to another type" do
      let(:type) { "users" }

      it "preserves the unrelated name" do
        expect(member_name).to eq("writer")
      end
    end
  end

  describe "#unscoped_member" do
    subject(:member_name) { glossary.unscoped_member(declared:) }

    let(:declared) { "writer" }

    it "preserves the name without applying resource renames" do
      expect(member_name).to eq("writer")
    end

    context "when the name has several words" do
      let(:declared) { "original_author" }

      it "converts the name to camel case" do
        expect(member_name).to eq("originalAuthor")
      end
    end
  end
end
