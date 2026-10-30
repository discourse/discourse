# frozen_string_literal: true

require_relative "support"

module JsonApiKitFilteringSpec
  class UserResource < JsonApiKit::Resource
    model User
    type :users

    attribute :username
    filter :username
  end

  class PostResource < JsonApiKit::Resource
    model Post
    type :posts

    attribute :post_number
    filter :post_number
    has_one :user, resource: UserResource
  end

  class TopicResource < JsonApiKit::Resource
    model Topic
    type :topics

    attribute :title
    filter :title
    filter "posts.number" do |scope, value|
      scope.where(id: Post.where(post_number: value).select(:topic_id))
    end
    has_many :posts, resource: PostResource
    has_many :ordered_posts, resource: PostResource
    includes "posts.user"
  end

  PostResource.has_one(:topic, resource: TopicResource)
  TopicResource.includes "posts.topic.posts"

  class TopicWithDottedFilterResource < TopicResource
    model Topic
    type :topics

    filter "posts.post_number" do |scope, value|
      scope.where(id: Post.where(post_number: value).select(:topic_id))
    end

    filter "#{"posts.topic." * 17}title" do |scope, value|
      scope.where(title: value)
    end
  end

  class RenamePosts < JsonApiKit::VersionChange
    resource :topics do
      renamed_relationship from: :comments, to: :posts
    end

    resource :posts do
      renamed_filter from: :number, to: :post_number
      renamed_relationship from: :author, to: :user
    end

    resource :users do
      renamed_filter from: :login, to: :username
    end
  end
end

RSpec.describe "a filtered listing" do
  include_context "with a listing of topics"

  let(:params) { { filter: { title: middle.title } } }

  it "keeps the rows the filter allows" do
    expect(document).to eq(data: [topic_object(middle)], included: [], links: links_of)
  end

  context "when the filter keeps no row" do
    let(:params) { { filter: { title: "No topic carries this title" } } }

    it "returns an empty listing" do
      expect(document).to eq(data: [], included: [], links: links_of)
    end
  end

  context "when the filter value is a list" do
    let(:params) { { sort: { createdAt: :asc }, filter: { title: [oldest.title, newest.title] } } }

    it "keeps a row for each value of the list" do
      expect(document).to eq(
        data: [topic_object(oldest), topic_object(newest)],
        included: [],
        links: links_of,
      )
    end
  end

  context "when the filter list contains only false" do
    let(:params) { { filter: { title: [false] } } }

    it "accepts the non-empty list" do
      expect(document).to eq(data: [], included: [], links: links_of)
    end
  end
end

RSpec.describe "filters for included resources" do
  include_context "with a listing of topics"

  fab!(:first_author) { Fabricate(:user, username: "first_author") }
  fab!(:second_author) { Fabricate(:user, username: "second_author") }
  fab!(:first_post) { Fabricate(:post, topic: middle, user: first_author, post_number: 1) }
  fab!(:second_post) { Fabricate(:post, topic: middle, user: second_author, post_number: 2) }

  let(:resource) { JsonApiKitFilteringSpec::TopicResource }
  let(:params) { { include: "posts", filter: { "posts.postNumber" => 2 } } }
  let(:included_ids) { document.fetch(:included).map { it.fetch(:id) } }
  let(:topic_data) { document.fetch(:data).detect { it.fetch(:id) == middle.id.to_s } }
  let(:post_links) { topic_data.dig(:relationships, "posts", :links) }
  let(:link_filters) do
    post_links.values_at(:self, :related).map { parameters_of(it).fetch("filter") }
  end

  it "limits filtering to the included posts", :aggregate_failures do
    expect(listed_ids).to contain_exactly(oldest.id.to_s, middle.id.to_s, newest.id.to_s)
    expect(included_ids).to contain_exactly(second_post.id.to_s)
  end

  it "keeps the related filter in its links" do
    expect(link_filters).to all(eq("postNumber" => "2"))
  end

  context "when the request omits the matching include" do
    let(:resource) { super().new(guardian:, edition:) }
    let(:params) { super().except(:include) }
    let(:post_resource) { resource.resource_for(JsonApiKitFilteringSpec::PostResource) }
    let(:post_reads) { track_sql_queries { document }.grep(/(?:FROM|JOIN) "posts"/) }

    before do
      allow(post_resource).to receive(:apply_filters).and_call_original
      post_reads
    end

    it "returns the topics without filtering or loading posts", :aggregate_failures do
      expect(listed_ids).to contain_exactly(oldest.id.to_s, middle.id.to_s, newest.id.to_s)
      expect(included_ids).to be_empty
      expect(post_reads).to be_empty
      expect(post_resource).not_to have_received(:apply_filters)
    end
  end

  context "when the request fetches one topic" do
    let(:document) { one_document(middle.id) }

    it "filters its included posts" do
      expect(included_ids).to contain_exactly(second_post.id.to_s)
    end
  end

  context "when the request also filters the primary collection" do
    let(:params) { super().deep_merge(filter: { title: middle.title }) }

    it "applies each filter to its resource", :aggregate_failures do
      expect(listed_ids).to eq([middle.id.to_s])
      expect(included_ids).to eq([second_post.id.to_s])
    end
  end

  context "when another relationship uses the same resource" do
    let(:params) { super().merge(include: "posts,orderedPosts") }

    it "keeps the other relationship's posts", :aggregate_failures do
      expect(topic_data.dig(:relationships, "posts", :data)).to eq(
        [identifier_of("posts", second_post)],
      )
      expect(topic_data.dig(:relationships, "orderedPosts", :data)).to contain_exactly(
        identifier_of("posts", first_post),
        identifier_of("posts", second_post),
      )
    end
  end

  context "when the primary resource declares a dotted filter" do
    let(:params) { super().merge(filter: { "posts.number" => 2 }) }

    it "keeps the declared filter on the primary resource", :aggregate_failures do
      expect(listed_ids).to eq([middle.id.to_s])
      expect(included_ids).to contain_exactly(first_post.id.to_s, second_post.id.to_s)
    end
  end

  context "when equivalent filters reach the same type through different resource classes" do
    let(:other_users) do
      Class.new(JsonApiKitFilteringSpec::UserResource) do
        model User
        type :users
      end
    end
    let(:other_posts) do
      Class
        .new(JsonApiKit::Resource) do
          model Post
          type :posts
          attribute :post_number
        end
        .tap { it.has_one(:user, resource: other_users) }
    end
    let(:resource) do
      Class
        .new(JsonApiKit::Resource) do
          model Topic
          type :topics
          attribute :title
          has_many :posts, resource: JsonApiKitFilteringSpec::PostResource
          includes "posts.user", "ordered_posts.user"
        end
        .tap { it.has_many(:ordered_posts, resource: other_posts) }
    end
    let(:params) do
      {
        include: "posts.user,orderedPosts.user",
        filter: {
          "posts.user.username" => first_author.username,
          "orderedPosts.user.username" => first_author.username,
        },
      }
    end
    let(:included_users) { document.fetch(:included).select { it.fetch(:type) == "users" } }

    it "merges the matching author" do
      expect(included_users).to contain_exactly(a_hash_including(id: first_author.id.to_s))
    end
  end

  context "when the filter targets a nested relationship" do
    let(:params) do
      { include: "posts.user", filter: { "posts.user.username" => first_author.username } }
    end
    let(:included_users) { document.fetch(:included).select { it.fetch(:type) == "users" } }

    it "filters the nested users" do
      expect(included_users).to contain_exactly(a_hash_including(id: first_author.id.to_s))
    end

    it "keeps the nested filter in its links" do
      expect(link_filters).to all(eq("user.username" => first_author.username))
    end

    context "when the edition renames the nested relationship and filter" do
      let(:edition) do
        JsonApiKit::Edition.new([JsonApiKitFilteringSpec::RenamePosts.new(__FILE__)])
      end
      let(:params) do
        { include: "comments.author", filter: { "comments.author.login" => first_author.username } }
      end
      let(:post_links) { topic_data.dig(:relationships, "comments", :links) }

      it "uses the historical nested path in its links" do
        expect(link_filters).to all(eq("author.login" => first_author.username))
      end
    end
  end

  context "when the edition renames the relationship and filter" do
    let(:resource) { JsonApiKitFilteringSpec::TopicWithDottedFilterResource }
    let(:edition) { JsonApiKit::Edition.new([JsonApiKitFilteringSpec::RenamePosts.new(__FILE__)]) }
    let(:params) { { include: "comments", filter: { "comments.number" => 2 } } }
    let(:post_links) { topic_data.dig(:relationships, "comments", :links) }

    it "resolves the filter through the requested edition" do
      expect(included_ids).to contain_exactly(second_post.id.to_s)
    end

    it "uses the historical filter name in its links" do
      expect(link_filters).to all(eq("number" => "2"))
    end

    it "keeps the historical relationship filter separate from the local dotted filter" do
      expect(listed_ids).to contain_exactly(oldest.id.to_s, middle.id.to_s, newest.id.to_s)
    end

    context "when the request also supplies the local dotted filter" do
      let(:params) { super().deep_merge(filter: { "posts.postNumber" => 1 }) }

      it "applies both filters to their resources", :aggregate_failures do
        expect(listed_ids).to eq([middle.id.to_s])
        expect(included_ids).to contain_exactly(second_post.id.to_s)
      end
    end

    context "when the request fetches one topic" do
      let(:document) { one_document(middle.id) }

      it "filters its included posts" do
        expect(included_ids).to contain_exactly(second_post.id.to_s)
      end
    end
  end

  context "when the relationship path does not exist" do
    let(:params) { super().merge(filter: { "missing.postNumber" => 2 }) }

    it "identifies the original filter parameter" do
      expect(document.fetch(:errors)).to contain_exactly(
        a_hash_including(status: "400", source: { parameter: "filter[missing.postNumber]" }),
      )
    end
  end

  context "when the related resource does not declare the filter" do
    let(:params) { super().merge(filter: { "posts.missing" => 2 }) }

    it "identifies the original filter parameter" do
      expect(document.fetch(:errors)).to contain_exactly(
        a_hash_including(status: "400", source: { parameter: "filter[posts.missing]" }),
      )
    end
  end

  context "when the related filter has an invalid value" do
    let(:params) { super().merge(filter: { "posts.postNumber" => { "unexpected" => 2 } }) }

    it "identifies the invalid filter value" do
      expect(document.fetch(:errors)).to contain_exactly(
        a_hash_including(
          status: "400",
          title: "Invalid filter value",
          source: {
            parameter: "filter[posts.postNumber]",
          },
        ),
      )
    end
  end

  context "when paths apply different filters to the same resource's relationship" do
    let(:params) do
      { include: "posts,posts.topic.posts", filter: { "posts.topic.posts.postNumber" => 1 } }
    end

    it "rejects conflicting relationship views" do
      expect(document.fetch(:errors)).to contain_exactly(
        a_hash_including(status: "400", source: { parameter: "filter" }),
      )
    end
  end

  context "when the filter traverses 32 relationships" do
    let(:filter_name) { "#{"posts.topic." * 16}title" }
    let(:params) { { filter: { filter_name => middle.title } } }

    it "accepts the filter without including related records", :aggregate_failures do
      expect(listed_ids).to contain_exactly(oldest.id.to_s, middle.id.to_s, newest.id.to_s)
      expect(included_ids).to be_empty
    end
  end

  context "when the filter traverses 33 relationships" do
    let(:filter_name) { "#{"posts.topic." * 16}posts.postNumber" }
    let(:params) { { filter: { filter_name => 2 } } }

    it "identifies the filter that exceeds the depth limit" do
      expect(document.fetch(:errors)).to contain_exactly(
        a_hash_including(
          status: "400",
          title: "Filter path too deep",
          detail: "Filter paths cannot traverse more than 32 relationships.",
          source: {
            parameter: "filter[#{filter_name}]",
          },
        ),
      )
    end
  end

  context "when the filter traverses 2,000 relationships" do
    let(:filter_name) { "#{"posts.topic." * 1000}title" }
    let(:params) { { filter: { filter_name => middle.title } } }

    it "rejects the filter without overflowing the stack" do
      expect(document.fetch(:errors)).to contain_exactly(
        a_hash_including(status: "400", source: { parameter: "filter[#{filter_name}]" }),
      )
    end
  end

  context "when a declared local filter name contains more than 32 dots" do
    let(:resource) { JsonApiKitFilteringSpec::TopicWithDottedFilterResource }
    let(:filter_name) { "#{"posts.topic." * 17}title" }
    let(:params) { { filter: { filter_name => middle.title } } }

    it "applies the local filter" do
      expect(listed_ids).to eq([middle.id.to_s])
    end
  end
end
