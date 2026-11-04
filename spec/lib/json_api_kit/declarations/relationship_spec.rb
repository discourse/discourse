# frozen_string_literal: true

RSpec::Matchers.alias_matcher :resolve, :be_resolves

RSpec.describe JsonApiKit::Declarations::Relationship do
  subject(:relationship) { described_class.new(:user, resource: users_resource) }

  let(:groups_resource) { Class.new(JsonApiKit::Resource) { type :groups } }
  let(:users_resource) do
    related = groups_resource

    Class.new(JsonApiKit::Resource) do
      model User
      type :users
      attribute :username
      has_many :groups, resource: related
    end
  end

  describe ".new" do
    context "when the readable block declares both a guardian and a record" do
      subject(:relationship) do
        described_class.new(
          :user,
          resource: users_resource,
          readable: ->(guardian, record) { true },
        )
      end

      it "raises an error" do
        expect { relationship }.to raise_error(described_class::UnsupportedRule, /user/)
      end
    end
  end

  describe "#resolves?" do
    let(:path) { JsonApiKit::Path.for("groups") }

    it { is_expected.to resolve(path) }

    context "when the resource on the other side holds no such relationship" do
      let(:path) { JsonApiKit::Path.for("members") }

      it { is_expected.not_to resolve(path) }
    end
  end

  describe described_class::ToMany do
    subject(:relationship) { described_class.new(:posts, resource: posts_resource) }

    let(:posts_resource) do
      Class.new(JsonApiKit::Resource) do
        type :posts
        page default: 2
      end
    end

    describe "#linkage" do
      subject(:linkage) { relationship.linkage(records) }

      let(:first_record) { instance_double(JsonApiKit::Record) }
      let(:second_record) { instance_double(JsonApiKit::Record, cursor: "next-cursor") }
      let(:third_record) { instance_double(JsonApiKit::Record) }
      let(:records) { JsonApiKit::Records.new([first_record, second_record, third_record]) }

      it "holds one page of them at the size the resource reads" do
        expect(linkage.records.to_a).to eq([first_record, second_record])
      end
    end
  end
end
