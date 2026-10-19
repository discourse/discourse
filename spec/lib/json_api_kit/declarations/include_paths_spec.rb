# frozen_string_literal: true

RSpec.describe JsonApiKit::Declarations::IncludePaths do
  subject(:include_paths) { described_class.new(deep_paths, relationships:) }

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
  let(:relationships) do
    JsonApiKit::Declarations::Relationships.new([user_relationship, tags_relationship])
  end
  let(:deep_paths) { %w[user.groups] }

  describe ".new" do
    context "when a path reaches a relationship no resource declares" do
      let(:deep_paths) { %w[user.members] }

      it "refuses the declaration" do
        expect { include_paths }.to raise_error(described_class::Unresolved, /user\.members/)
      end
    end
  end

  describe "#allow" do
    subject(:allow) { include_paths.allow(JsonApiKit::Paths.new(paths)) }

    let(:paths) { %w[user] }

    it "returns those paths" do
      expect(allow.map(&:to_s)).to eq(%w[user])
    end

    context "when the paths hold every relationship" do
      let(:paths) { %w[user tags] }

      it "allows the request" do
        expect { allow }.not_to raise_error
      end
    end

    context "when the paths reach two levels deep" do
      let(:paths) { %w[user.groups] }

      it "allows the request" do
        expect { allow }.not_to raise_error
      end
    end

    context "when the paths are empty" do
      let(:paths) { [] }

      it "allows the request" do
        expect { allow }.not_to raise_error
      end
    end

    context "when a reading is part way along the path" do
      subject(:allow) { include_paths.allow(entered_paths) }

      let(:entered_paths) { JsonApiKit::Paths.new(%w[user.groups.members]).next_for("user") }

      it "allows a path the resource never declares" do
        expect { allow }.not_to raise_error
      end
    end

    context "when the paths hold an unknown relationship" do
      let(:paths) { %w[secrets] }

      it "refuses the request" do
        expect { allow }.to raise_error(KeyError, /secrets/)
      end
    end

    context "when a request reads past a relationship the resource declares" do
      let(:paths) { %w[tags.topics] }

      it "refuses the request" do
        expect { allow }.to raise_error(KeyError)
      end
    end

    context "when a request reads past a path the resource declares" do
      let(:paths) { %w[user.groups.users] }

      it "refuses the request" do
        expect { allow }.to raise_error(KeyError)
      end
    end
  end

  describe "#include?" do
    subject { include_paths }

    let(:path) { JsonApiKit::Path.for("user") }

    it { is_expected.to include(path) }

    context "when the path is an unknown relationship" do
      let(:path) { JsonApiKit::Path.for("secrets") }

      it { is_expected.not_to include(path) }
    end
  end
end
