# frozen_string_literal: true

module JsonApiKitSpec
  class GroupResource < JsonApiKit::Resource
    model Group
    type :groups

    attribute :name
  end

  class UserResource < JsonApiKit::Resource
    model User
    type :users

    attribute :username

    has_many :groups, resource: GroupResource
  end

  GroupResource.has_many(:users, resource: UserResource)

  class CategoryResource < JsonApiKit::Resource
    model Category
    type :categories

    attribute :name
  end

  class TagResource < JsonApiKit::Resource
    model Tag
    type :tags

    attribute :name
  end

  class PostResource < JsonApiKit::Resource
    model Post
    type :posts

    sort :post_number
    default_sort post_number: :asc
    page default: 2, max: 10

    attribute :post_number

    has_one :user, resource: UserResource
  end

  class TopicResource < JsonApiKit::Resource
    model Topic
    type :topics

    sort :created_at
    sort :title
    sort :last_posted_at
    default_sort created_at: :desc

    filter :title

    anchor :id
    anchor :created_at
    anchor :title
    anchor :last_posted_at
    anchor(:mine) { |topics, guardian| topics.where(user_id: guardian.user&.id) }

    attribute :title
    attribute :created_at

    has_one :user, resource: UserResource
    has_one :category, resource: CategoryResource
    has_many :tags, resource: TagResource
    has_many :posts, resource: PostResource

    includes "user.groups", "user.groups.users", "posts.topic", "posts.user", "posts.user.groups"
  end

  PostResource.has_one(:topic, resource: TopicResource)
end

RSpec.shared_context "with a listing of topics" do
  fab!(:oldest) do
    Fabricate(:topic, title: "Anchors and centred pages", created_at: Time.utc(2026, 8, 1))
  end
  fab!(:middle) do
    Fabricate(:topic, title: "Cursors that survive a redesign", created_at: Time.utc(2026, 8, 2))
  end
  fab!(:newest) do
    Fabricate(:topic, title: "Bands of a segmented listing", created_at: Time.utc(2026, 8, 3))
  end

  let(:resource) { JsonApiKitSpec::TopicResource }
  let(:guardian) { Guardian.new }
  let(:params) { {} }
  let(:base) { "https://example.com/api" }
  let(:current) { "https://example.com/api/topics" }
  let(:query) { {} }
  let(:scoped_to) { nil }
  let(:urls) { JsonApiKit::Urls.new(base:, current:, parameters: query) }

  let(:document) do
    JsonApiKit::Document::Collection.for(params, resource:, guardian:, urls:, scoped_to:).to_h
  end

  def one_document(id, **options)
    JsonApiKit::Document::Individual.for(id, params, resource:, guardian:, urls:, **options).to_h
  end

  def listing_of(parameters)
    JsonApiKit::Document::Collection.for(
      parameters,
      resource:,
      guardian:,
      urls: JsonApiKit::Urls.new(base:, current:),
      scoped_to:,
    ).to_h
  end

  def cursor_of(row) = row[:meta][:page][:cursor]

  def topic_object(topic, fields: %w[title created_at], **members)
    resource_object(
      "topics",
      topic,
      { "title" => topic.title, "created_at" => topic.created_at }.slice(*fields),
      **members,
    )
  end

  def user_object(user, fields: %w[username], **members)
    resource_object("users", user, { "username" => user.username }.slice(*fields), **members)
  end

  def group_object(group, fields: %w[name], **members)
    resource_object("groups", group, { "name" => group.name }.slice(*fields), **members)
  end

  def category_object(category, fields: %w[name], **members)
    resource_object("categories", category, { "name" => category.name }.slice(*fields), **members)
  end

  def tag_object(tag, fields: %w[name], **members)
    resource_object("tags", tag, { "name" => tag.name }.slice(*fields), **members)
  end

  def post_object(post, fields: %w[post_number], **members)
    resource_object("posts", post, { "post_number" => post.post_number }.slice(*fields), **members)
  end

  def resource_object(type, row, attributes, cursor: nil, relationships: nil)
    {
      type:,
      id: row.id.to_s,
      attributes: attributes.presence,
      relationships:,
      meta: cursor && { page: { cursor: } },
      links: {
        self: "#{base}/#{type}/#{row.id}",
      },
    }.compact
  end

  def relationship_object(type, row, name, data:)
    {
      data:,
      links: {
        self: "#{base}/#{type}/#{row.id}/relationships/#{name}",
        related: "#{base}/#{type}/#{row.id}/#{name}",
      },
    }
  end

  def identifier_of(type, row) = { type:, id: row.id.to_s }

  def paged_relationship_object(type, row, name, data:, next_page: nil)
    relationship_object(type, row, name, data:).deep_merge(links: { prev: nil, next: next_page })
  end

  def refusal(title:, detail:, parameter: nil, status: "400", **members)
    { status:, title:, detail:, source: parameter && { parameter: }, **members }.compact
  end

  def not_found = refusal(status: "404", title: "No such record", detail: "No record has this ID.")

  def profile_link(name) = "https://jsonapi.org/profiles/ethanresnick/cursor-pagination/#{name}"

  def self_link
    href = query.blank? ? current : "#{current}?#{query.to_query}"
    { href:, type: JsonApiKit::Pagination::Profile::MEDIA_TYPE }
  end

  def links_of(**pages) = { self: self_link, **{ prev: nil, next: nil }.merge(pages) }

  def page_url(**page) = "#{current}?#{query.except("page").merge(page:).to_query}"

  def cursor_at(index, rendered = document) = cursor_of(rendered[:data][index])

  def cursor_of_record(record, of: resource, sort: {})
    of.order(sort).first.position_of(record).to_cursor.to_s
  end

  def relationship_page_url(type, row, name, **page)
    "#{base}/#{type}/#{row.id}/#{name}?#{{ page: page }.to_query}"
  end

  def listed_ids(rendered = document) = rendered[:data].map { it[:id] }

  def rendered_error(rendered = document) = rendered[:errors].sole
end
