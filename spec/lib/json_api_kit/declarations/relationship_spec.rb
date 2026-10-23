# frozen_string_literal: true

RSpec::Matchers.alias_matcher :resolve, :be_resolves

RSpec.describe JsonApiKit::Declarations::Relationship do
  subject(:relationship) { described_class.new(:user, resource: users_resource) }

  fab!(:author, :user)
  fab!(:topic) { Fabricate(:topic, user: author, title: "A topic that relates to rows") }

  let(:guardian) { Guardian.new }

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

    fab!(:first_post) { Fabricate(:post, topic:) }
    fab!(:second_post) { Fabricate(:post, topic:) }
    fab!(:third_post) { Fabricate(:post, topic:) }
    fab!(:elsewhere, :post)

    let(:posts_resource) do
      Class.new(JsonApiKit::Resource) do
        model Post
        type :posts
        page default: 2
      end
    end

    describe "#linkage" do
      subject(:linkage) { relationship.linkage(records) }

      let(:order) { posts_resource.order({}) }
      let(:records) do
        JsonApiKit::Records.new(
          [first_post, second_post, third_post].map do
            JsonApiKit::Record.new(
              JsonApiKit::Adapters::ActiveRecord::Pagination::Row.new(
                record: it,
                segment: order.first,
              ),
              posts_resource.fields(guardian:),
              type: "posts",
            )
          end,
        )
      end

      it "holds one page of them at the size the resource reads" do
        expect(linkage.records.map(&:record)).to eq([first_post, second_post])
      end
    end
  end
end
