# frozen_string_literal: true

require_relative "support"

RSpec.describe "a document with related records" do
  include_context "with a listing of topics"

  fab!(:author) { Fabricate(:user, username: "the_author") }
  fab!(:group) { Fabricate(:group, name: "everyone_who_writes").tap { it.add(author) } }
  fab!(:category) { Fabricate(:category, name: "Where the topic sits") }
  fab!(:tag) { Fabricate(:tag, name: "a-tag-it-carries") }
  fab!(:topic) do
    Fabricate(
      :topic,
      user: author,
      category:,
      title: "A topic that has relations",
      created_at: Time.utc(2026, 8, 4),
    )
  end
  fab!(:tagging) { Fabricate(:topic_tag, topic:, tag:) }

  let(:scoped_to) { Topic.where(id: topic.id) }
  let(:params) { { include: %w[user] } }

  describe "a relationship to one record" do
    it "renders the row and its related record" do
      expect(document).to eq(
        data: [
          topic_object(
            topic,
            relationships: {
              "user" =>
                relationship_object("topics", topic, "user", data: identifier_of("users", author)),
            },
          ),
        ],
        included: [user_object(author)],
        links: links_of,
      )
    end

    context "when the page holds more rows than the related resource's default page" do
      fab!(:topics_by_many_users) do
        Array.new(JsonApiKit::Page::Limits::DEFAULT + 1) do
          Fabricate(:topic, user: Fabricate(:user))
        end
      end

      let(:scoped_to) { Topic.where(id: topics_by_many_users) }
      let(:params) { { include: %w[user], page: { size: topics_by_many_users.size } } }

      it "renders a related record for every row" do
        expect(document[:included].map { it[:id] }).to match_array(
          topics_by_many_users.map { it.user_id.to_s },
        )
      end
    end
  end

  context "when the request asks for no relationship" do
    let(:params) { {} }

    it "renders no relationship and no related record" do
      expect(document).to eq(data: [topic_object(topic)], included: [], links: links_of)
    end
  end

  context "when the relationship holds no record" do
    fab!(:bare) do
      Fabricate(
        :private_message_topic,
        title: "A topic in no category at all",
        created_at: Time.utc(2026, 8, 6),
      )
    end

    let(:scoped_to) { Topic.where(id: bare.id) }
    let(:params) { { include: %w[category] } }

    it "links the row to no record" do
      expect(document).to eq(
        data: [
          topic_object(
            bare,
            relationships: {
              "category" => relationship_object("topics", bare, "category", data: nil),
            },
          ),
        ],
        included: [],
        links: links_of,
      )
    end
  end

  describe "a relationship to many records" do
    let(:params) { { include: %w[tags] } }

    it "renders the row and every related record" do
      expect(document).to eq(
        data: [
          topic_object(
            topic,
            relationships: {
              "tags" =>
                paged_relationship_object(
                  "topics",
                  topic,
                  "tags",
                  data: [identifier_of("tags", tag)],
                ),
            },
          ),
        ],
        included: [tag_object(tag)],
        links: links_of,
      )
    end

    context "when the relationship holds no record" do
      let(:scoped_to) { Topic.where(id: oldest.id) }

      it "links the row to an empty list" do
        expect(document).to eq(
          data: [
            topic_object(
              oldest,
              relationships: {
                "tags" => paged_relationship_object("topics", oldest, "tags", data: []),
              },
            ),
          ],
          included: [],
          links: links_of,
        )
      end
    end
  end

  describe "a path through one relationship" do
    let(:params) { { include: %w[user.groups] } }

    it "renders every record of the path" do
      expect(document).to eq(
        data: [
          topic_object(
            topic,
            relationships: {
              "user" =>
                relationship_object("topics", topic, "user", data: identifier_of("users", author)),
            },
          ),
        ],
        included: [
          user_object(
            author,
            relationships: {
              "groups" =>
                paged_relationship_object(
                  "users",
                  author,
                  "groups",
                  data: [identifier_of("groups", group)],
                ),
            },
          ),
          group_object(group),
        ],
        links: links_of,
      )
    end
  end

  describe "a path through three relationships" do
    let(:params) { { include: %w[user.groups.users] } }

    it "renders every record of the path one time" do
      expect(document).to eq(
        data: [
          topic_object(
            topic,
            relationships: {
              "user" =>
                relationship_object("topics", topic, "user", data: identifier_of("users", author)),
            },
          ),
        ],
        included: [
          user_object(
            author,
            relationships: {
              "groups" =>
                paged_relationship_object(
                  "users",
                  author,
                  "groups",
                  data: [identifier_of("groups", group)],
                ),
            },
          ),
          group_object(
            group,
            relationships: {
              "users" =>
                paged_relationship_object(
                  "groups",
                  group,
                  "users",
                  data: [identifier_of("users", author)],
                ),
            },
          ),
        ],
        links: links_of,
      )
    end
  end

  describe "a record two rows reach" do
    fab!(:another) do
      Fabricate(
        :topic,
        user: author,
        title: "Another topic by the same author",
        created_at: Time.utc(2026, 8, 5),
      )
    end

    let(:scoped_to) { Topic.where(id: [topic.id, another.id]) }

    it "renders it one time for both rows" do
      expect(document).to eq(
        data: [
          topic_object(
            another,
            relationships: {
              "user" =>
                relationship_object(
                  "topics",
                  another,
                  "user",
                  data: identifier_of("users", author),
                ),
            },
          ),
          topic_object(
            topic,
            relationships: {
              "user" =>
                relationship_object("topics", topic, "user", data: identifier_of("users", author)),
            },
          ),
        ],
        included: [user_object(author)],
        links: links_of,
      )
    end
  end

  describe "a record two paths reach" do
    fab!(:post) { Fabricate(:post, topic:, user: author) }

    let(:params) { { include: %w[user posts.user.groups] } }

    it "renders it one time with its relationships" do
      expect(document).to eq(
        data: [
          topic_object(
            topic,
            relationships: {
              "user" =>
                relationship_object("topics", topic, "user", data: identifier_of("users", author)),
              "posts" =>
                paged_relationship_object(
                  "topics",
                  topic,
                  "posts",
                  data: [identifier_of("posts", post)],
                ),
            },
          ),
        ],
        included: [
          user_object(
            author,
            relationships: {
              "groups" =>
                paged_relationship_object(
                  "users",
                  author,
                  "groups",
                  data: [identifier_of("groups", group)],
                ),
            },
          ),
          post_object(
            post,
            relationships: {
              "user" =>
                relationship_object("posts", post, "user", data: identifier_of("users", author)),
            },
          ),
          group_object(group),
        ],
        links: links_of,
      )
    end
  end

  context "when the path returns to the row it starts from" do
    fab!(:post) { Fabricate(:post, topic:) }

    let(:params) { { include: %w[posts.topic] } }

    it "renders every record one time" do
      expect(document).to eq(
        data: [
          topic_object(
            topic,
            relationships: {
              "posts" =>
                paged_relationship_object(
                  "topics",
                  topic,
                  "posts",
                  data: [identifier_of("posts", post)],
                ),
            },
          ),
        ],
        included: [
          post_object(
            post,
            relationships: {
              "topic" =>
                relationship_object("posts", post, "topic", data: identifier_of("topics", topic)),
            },
          ),
        ],
        links: links_of,
      )
    end
  end

  context "when the scope of a related resource hides the record" do
    let(:resource) do
      staff =
        Class.new(JsonApiKit::Resource) do
          model User
          type :users
          scope { |guardian| User.where(admin: true) }
          attribute :username
        end

      Class.new(JsonApiKit::Resource) do
        model Topic
        type :topics
        attribute :title
        has_one :user, resource: staff
      end
    end

    it "links the row to no record" do
      expect(document).to eq(
        data: [
          topic_object(
            topic,
            fields: %w[title],
            relationships: {
              "user" => relationship_object("topics", topic, "user", data: nil),
            },
          ),
        ],
        included: [],
        links: links_of,
      )
    end
  end

  describe "a page of rows" do
    fab!(:another) { Fabricate(:topic, title: "One more topic alongside") }

    let(:scoped_to) { Topic.where(id: [topic.id, another.id]) }

    def reads_of_users(&block) = track_sql_queries(&block).grep(/FROM "users"/).size

    it "reads the related records in one query" do
      expect(reads_of_users { document }).to eq(1)
    end

    context "when the page is centred on an anchor" do
      let(:params) do
        { include: %w[user], page: { anchor: { id: topic.id }, before_size: 1, after_size: 1 } }
      end

      it "reads them in one query" do
        expect(reads_of_users { document }).to eq(1)
      end
    end
  end

  describe "a relationship holding more records than one page" do
    fab!(:posts) { 3.times.map { Fabricate(:post, topic:) } }

    let(:params) { { include: %w[posts] } }

    def next_page_of(row, post)
      "#{base}/topics/#{row.id}/relationships/posts?" +
        { page: { after: cursor_of_record(post, of: JsonApiKitSpec::PostResource) } }.to_query
    end

    it "renders one page of them and links to the next" do
      expect(document).to eq(
        data: [
          topic_object(
            topic,
            relationships: {
              "posts" =>
                paged_relationship_object(
                  "topics",
                  topic,
                  "posts",
                  data: posts.first(2).map { identifier_of("posts", it) },
                  next_page: next_page_of(topic, posts.second),
                ),
            },
          ),
        ],
        included: posts.first(2).map { post_object(it) },
        links: links_of,
      )
    end

    context "when the request reads the page after them" do
      let(:resource) { JsonApiKitSpec::PostResource }
      let(:current) { "#{base}/posts" }
      let(:scoped_to) { topic.posts }
      let(:params) { { page: { after: cursor_of_record(posts.second) } } }

      it "returns the records after them" do
        expect(document).to eq(
          data: [post_object(posts.third)],
          included: [],
          links: links_of(prev: page_url(before: cursor_of_record(posts.third))),
        )
      end
    end

    context "when the page holds several rows" do
      fab!(:another) do
        Fabricate(:topic, title: "Another topic carrying replies", created_at: Time.utc(2026, 8, 5))
      end
      fab!(:more) { 3.times.map { Fabricate(:post, topic: another) } }

      let(:scoped_to) { Topic.where(id: [topic.id, another.id]) }

      it "renders one page of them for every row" do
        expect(document).to eq(
          data: [
            topic_object(
              another,
              relationships: {
                "posts" =>
                  paged_relationship_object(
                    "topics",
                    another,
                    "posts",
                    data: more.first(2).map { identifier_of("posts", it) },
                    next_page: next_page_of(another, more.second),
                  ),
              },
            ),
            topic_object(
              topic,
              relationships: {
                "posts" =>
                  paged_relationship_object(
                    "topics",
                    topic,
                    "posts",
                    data: posts.first(2).map { identifier_of("posts", it) },
                    next_page: next_page_of(topic, posts.second),
                  ),
              },
            ),
          ],
          included: [*more.first(2), *posts.first(2)].map { post_object(it) },
          links: links_of,
        )
      end

      it "reads the related records in one query" do
        expect(track_sql_queries { document }.grep(/FROM "posts"/).size).to eq(1)
      end
    end
  end

  describe "one record" do
    let(:params) { { include: %w[user] } }
    let(:query) { { "include" => "user" } }
    let(:current) { "#{base}/topics/#{topic.id}" }

    it "renders the record with what it relates to" do
      expect(one_document(topic.id)).to eq(
        data:
          topic_object(
            topic,
            relationships: {
              "user" =>
                relationship_object("topics", topic, "user", data: identifier_of("users", author)),
            },
          ),
        included: [user_object(author)],
        links: {
          self: self_link,
        },
      )
    end
  end
end
