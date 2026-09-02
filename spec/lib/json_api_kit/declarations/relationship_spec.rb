# frozen_string_literal: true

RSpec::Matchers.alias_matcher :resolve, :be_resolves

RSpec.describe JsonApiKit::Declarations::Relationship do
  subject(:relationship) { described_class.new(:user, resource: users_resource) }

  fab!(:author, :user)
  fab!(:topic) { Fabricate(:topic, user: author, title: "A topic that relates to rows") }

  let(:guardian) { Guardian.new }

  let(:requested) { JsonApiKit::Page::Requested.for }
  let(:users_resource) do
    related = groups_resource

    Class.new(JsonApiKit::Resource) do
      model User
      type :users
      attribute :username
      has_many :groups, resource: related
    end
  end
  let(:groups_resource) { Class.new(JsonApiKit::Resource) { type :groups } }

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

  describe "#listing" do
    subject(:related_listing) { relationship.listing(params, guardian:, scoped_to:) }

    let(:params) { { fields: { "users" => %w[username] } } }
    let(:guardian) { Guardian.new(author) }
    let(:scoped_to) { JsonApiKit::Scoping.for(User.where(id: author.id)) }
    let(:listing) { instance_double(JsonApiKit::Query::Collection) }

    before { allow(users_resource).to receive(:all).and_return(listing) }

    it "asks the resource on the other side for a listing" do
      related_listing

      expect(users_resource).to have_received(:all).with(params, guardian:, scoped_to:)
    end

    it "returns the listing that resource reads" do
      expect(related_listing).to be(listing)
    end
  end

  describe "#resolves?" do
    subject { relationship }

    let(:path) { JsonApiKit::Path.for("groups") }

    it { is_expected.to resolve(path) }

    context "when the resource on the other side holds no such relationship" do
      let(:path) { JsonApiKit::Path.for("members") }

      it { is_expected.not_to resolve(path) }
    end
  end

  describe described_class::ToOne do
    subject(:relationship) { described_class.new(:user, resource: users_resource) }

    describe "#scoping" do
      subject(:scoping) { relationship.scoping(association) }

      let(:association) { JsonApiKit::Schema.new(Topic).association(:user, [topic]) }

      it "keeps the listing to the rows the owners reach" do
        expect(scoping.apply(User.all)).to eq([author])
      end

      it "reads one page for each owner" do
        expect(scoping.page(requested)).to be_a(JsonApiKit::Page::PerOwner)
      end
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

    describe "#scoping" do
      subject(:scoping) { relationship.scoping(association) }

      let(:association) { JsonApiKit::Schema.new(Topic).association(:posts, [topic]) }

      it "keeps the listing to the rows the owners reach" do
        expect(scoping.apply(Post.all)).to contain_exactly(first_post, second_post, third_post)
      end

      it "reads one page for each owner" do
        expect(scoping.page(requested)).to be_a(JsonApiKit::Page::PerOwner)
      end
    end

    describe "#linkage" do
      subject(:linkage) { relationship.linkage(records) }

      let(:order) { posts_resource.order }
      let(:records) do
        JsonApiKit::Records.new(
          [first_post, second_post, third_post].map do
            JsonApiKit::Record.new(
              JsonApiKit::Pagination::Row.new(record: it, segment: order.first),
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
