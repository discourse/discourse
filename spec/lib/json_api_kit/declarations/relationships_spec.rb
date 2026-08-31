# frozen_string_literal: true

RSpec::Matchers.alias_matcher :resolve, :be_resolves

RSpec.describe JsonApiKit::Declarations::Relationships do
  subject(:relationships) { described_class.new(declarations) }

  let(:groups_resource) { Class.new(JsonApiKit::Resource) { type :groups } }
  let(:users_resource) do
    related = groups_resource

    Class.new(JsonApiKit::Resource) do
      type :users
      has_many :groups, resource: related
    end
  end
  let(:user_relationship) do
    JsonApiKit::Declarations::Relationship::ToOne.new(:user, resource: users_resource)
  end
  let(:tags_relationship) do
    JsonApiKit::Declarations::Relationship::ToMany.new(:tags, resource: users_resource)
  end
  let(:declarations) { [user_relationship, tags_relationship] }

  describe "#pick" do
    it "returns every one of them" do
      expect(relationships.pick(%w[user tags])).to eq([user_relationship, tags_relationship])
    end

    it "leaves out the relationships a request does not name" do
      expect(relationships.pick(%w[user])).to eq([user_relationship])
    end

    context "when the list is empty" do
      it "returns no relationship" do
        expect(relationships.pick([])).to be_empty
      end
    end

    context "when it holds only one of the two" do
      subject(:relationships) { described_class.new([tags_relationship]) }

      it "leaves that name out" do
        expect(relationships.pick(%w[user tags])).to eq([tags_relationship])
      end
    end
  end

  describe "#names" do
    it "returns the name of every relationship it holds" do
      expect(relationships.names).to eq(%w[user tags])
    end
  end

  describe "#paths" do
    it "returns one path for each relationship it holds" do
      expect(relationships.paths.map(&:to_s)).to eq(%w[user tags])
    end
  end

  describe "#resolves?" do
    subject { relationships }

    let(:path) { JsonApiKit::Path.for("user") }

    it { is_expected.to resolve(path) }

    context "when it holds no relationship of that name" do
      let(:path) { JsonApiKit::Path.for("author") }

      it { is_expected.not_to resolve(path) }
    end

    context "when the path reads past a relationship" do
      let(:path) { JsonApiKit::Path.for("user.groups") }

      it { is_expected.to resolve(path) }
    end

    context "when the resource on the other side holds no such relationship" do
      let(:path) { JsonApiKit::Path.for("user.members") }

      it { is_expected.not_to resolve(path) }
    end
  end
end
