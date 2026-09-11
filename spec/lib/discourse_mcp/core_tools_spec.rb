# frozen_string_literal: true

describe DiscourseMcp::Tools::GetUser do
  fab!(:viewer, :admin)
  fab!(:user) { Fabricate(:user, name: "Hidden Name") }

  it "hides full names when names are disabled" do
    SiteSetting.enable_names = false
    request_context = instance_double(DiscourseMcp::RequestContext, guardian: viewer.guardian)

    result = described_class.call(arguments: { "username" => user.username }, request_context:)

    expect(result.dig(:structuredContent, :name)).to be_nil
  end
end

describe DiscourseMcp::Tools::FilterTopics do
  fab!(:viewer, :user)
  fab!(:member, :user)
  fab!(:moderator)
  fab!(:admin)
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group:) }
  fab!(:public_topic, :topic)
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }

  before { group.add(member) }

  it "filters topics using each caller's category access" do
    query = "topic:#{public_topic.id},#{private_topic.id}"

    expectations = {
      viewer => [public_topic.id],
      moderator => [public_topic.id],
      member => [public_topic.id, private_topic.id],
      admin => [public_topic.id, private_topic.id],
    }

    expectations.each do |user, expected_ids|
      request_context =
        instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
      result =
        described_class.call(
          arguments: {
            "filter" => query,
            "view" => "filtered",
          },
          request_context:,
        )

      expect(result.dig(:structuredContent, :results).pluck(:id)).to eq(expected_ids)
    end
  end

  it "honors the setting that removes automatic admin access to secured categories" do
    SiteSetting.suppress_secured_categories_from_admin = true
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: admin, guardian: admin.guardian)

    result =
      described_class.call(
        arguments: {
          "filter" => "topic:#{public_topic.id},#{private_topic.id}",
          "view" => "filtered",
        },
        request_context:,
      )

    expect(result.dig(:structuredContent, :results).pluck(:id)).to eq([public_topic.id])
  end

  it "returns truthful pagination and the requested top view" do
    TopTopic.create!(topic: public_topic, weekly_score: 2, daily_score: 1)
    second_topic = Fabricate(:topic)
    TopTopic.create!(topic: second_topic, weekly_score: 1, daily_score: 2)
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)

    first_page =
      described_class.call(
        arguments: {
          "view" => "top",
          "top_period" => "weekly",
          "page" => 0,
          "per_page" => 1,
        },
        request_context:,
      ).fetch(:structuredContent)
    second_page =
      described_class.call(
        arguments: {
          "view" => "top",
          "top_period" => "weekly",
          "page" => 1,
          "per_page" => 1,
        },
        request_context:,
      ).fetch(:structuredContent)
    hot =
      described_class.call(
        arguments: {
          "view" => "hot",
          "page" => 0,
          "per_page" => 1,
        },
        request_context:,
      ).fetch(:structuredContent)

    expect(first_page[:results].sole[:id]).to eq(public_topic.id)
    expect(first_page[:meta]).to eq(
      view: "top",
      top_period: "weekly",
      page: 0,
      per_page: 1,
      returned: 1,
      has_more: true,
    )
    expect(second_page[:results].sole[:id]).to eq(second_topic.id)
    expect(second_page[:meta]).to include(page: 1, returned: 1, has_more: false)
    expect(hot[:results].sole[:id]).to eq(second_topic.id)
    expect(hot[:meta][:top_period]).to eq("daily")
  end

  it "rejects options that do not belong to the selected view" do
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)

    expect do
      described_class.call(arguments: { "view" => "filtered" }, request_context:)
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.filter_required"))

    expect do
      described_class.call(
        arguments: {
          "view" => "hot",
          "filter" => "status:open",
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.filter_only_for_filtered_view"))
  end
end

describe DiscourseMcp::Tools::SearchPosts do
  fab!(:viewer, :user)
  fab!(:member, :user)
  fab!(:moderator)
  fab!(:admin)
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group:) }
  fab!(:public_post) { Fabricate(:post, raw: "parityneedle public evidence") }
  fab!(:private_topic) { Fabricate(:topic, category: private_category) }
  fab!(:private_post) do
    Fabricate(:post, topic: private_topic, raw: "parityneedle private evidence")
  end

  before do
    group.add(member)
    SearchIndexer.enable
    [public_post, private_post].each { |post| SearchIndexer.index(post, force: true) }
  end

  after { SearchIndexer.disable }

  it "returns matched post evidence using each caller's category access" do
    expectations = {
      viewer => [public_post.id],
      moderator => [public_post.id],
      member => [public_post.id, private_post.id],
      admin => [public_post.id, private_post.id],
    }

    expectations.each do |user, expected_ids|
      request_context =
        instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
      result =
        described_class.call(
          arguments: {
            "query" => "parityneedle",
            "page" => 1,
          },
          request_context:,
        ).fetch(:structuredContent)

      expect(result[:posts].pluck(:id)).to contain_exactly(*expected_ids)
      expect(result[:posts].pluck(:excerpt).join).to include("parityneedle")
      expect(result[:meta]).to include(page: 1, returned: expected_ids.length, exhaustive: false)
    end
  end

  it "honors the setting that removes automatic admin access to secured categories" do
    SiteSetting.suppress_secured_categories_from_admin = true
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: admin, guardian: admin.guardian)

    result =
      described_class.call(arguments: { "query" => "parityneedle", "page" => 1 }, request_context:)

    expect(result.dig(:structuredContent, :posts).pluck(:id)).to eq([public_post.id])
  end

  it "reports truthful bounded continuation" do
    SiteSetting.search_page_size = 1
    second_post = Fabricate(:post, raw: "paginationneedle second evidence")
    first_post = Fabricate(:post, raw: "paginationneedle first evidence")
    [first_post, second_post].each { |post| SearchIndexer.index(post, force: true) }
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)

    first_page =
      described_class.call(
        arguments: {
          "query" => "paginationneedle order:latest",
          "page" => 1,
        },
        request_context:,
      ).fetch(:structuredContent)
    second_page =
      described_class.call(
        arguments: {
          "query" => "paginationneedle order:latest",
          "page" => 2,
        },
        request_context:,
      ).fetch(:structuredContent)

    expect(first_page[:posts].sole[:id]).to eq(first_post.id)
    expect(first_page[:meta]).to include(page: 1, returned: 1, has_more: true)
    expect(second_page[:posts].sole[:id]).to eq(second_post.id)
    expect(second_page[:meta]).to include(page: 2, returned: 1, has_more: false)
  end

  it "searches private messages only for participants" do
    author = Fabricate(:user)
    message =
      Fabricate(
        :private_message_post,
        user: author,
        recipient: member,
        raw: "privatesearchneedle evidence",
      )
    SearchIndexer.index(message, force: true)

    expectations = {
      viewer => [],
      moderator => [],
      member => [message.id],
      author => [message.id],
      admin => [],
    }

    expectations.each do |user, expected_ids|
      request_context =
        instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
      result =
        described_class.call(
          arguments: {
            "query" => "in:messages privatesearchneedle",
          },
          request_context:,
        )

      expect(result.dig(:structuredContent, :posts).pluck(:id)).to eq(expected_ids)
    end
  end

  it "rejects a search term that Discourse cannot execute" do
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)

    expect do
      described_class.call(arguments: { "query" => "x" }, request_context:)
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.invalid_search_query"))
  end
end

describe DiscourseMcp::Tools::ReadTopicPosts do
  fab!(:viewer, :user)
  fab!(:member, :user)
  fab!(:moderator)
  fab!(:admin)
  fab!(:author, :user)
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group:) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category, user: author) }
  fab!(:private_post) do
    Fabricate(:post, topic: private_topic, user: author, raw: "restricted evidence")
  end

  before { group.add(member) }

  it "reads a secured topic only for callers with category access" do
    expectations = { viewer => false, moderator => false, member => true, admin => true }

    expectations.each do |user, allowed|
      request_context =
        instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
      operation =
        lambda do
          described_class.call(
            arguments: {
              "topic_id" => private_post.topic_id,
              "selection_mode" => "earliest",
            },
            request_context:,
          )
        end

      if allowed
        expect(operation.call.dig(:structuredContent, :posts).sole[:raw]).to eq(private_post.raw)
      else
        expect(&operation).to raise_error(DiscourseMcp::ToolError)
      end
    end
  end

  it "honors the setting that removes automatic admin access to secured categories" do
    SiteSetting.suppress_secured_categories_from_admin = true
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: admin, guardian: admin.guardian)

    expect do
      described_class.call(
        arguments: {
          "topic_id" => private_post.topic_id,
          "selection_mode" => "earliest",
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError)
  end

  it "reads a private message only for participants and admins" do
    message = Fabricate(:private_message_post, user: author, recipient: member)
    expectations = { viewer => false, moderator => false, member => true, admin => true }

    expectations.each do |user, allowed|
      request_context =
        instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
      operation =
        lambda do
          described_class.call(
            arguments: {
              "topic_id" => message.topic_id,
              "selection_mode" => "post_ids",
              "post_ids" => [message.id],
            },
            request_context:,
          )
        end

      if allowed
        expect(operation.call.dig(:structuredContent, :posts).sole[:raw]).to eq(message.raw)
      else
        expect(&operation).to raise_error(DiscourseMcp::ToolError)
      end
    end
  end

  it "reads a deleted topic only for staff who may see deleted topics" do
    deleted_post = Fabricate(:post, user: author, raw: "deleted topic evidence")
    deleted_post.topic.update!(deleted_at: 1.minute.ago)
    expectations = { viewer => false, moderator => true, admin => true }

    expectations.each do |user, allowed|
      aggregate_failures(user.username) do
        request_context =
          instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
        operation =
          lambda do
            described_class.call(
              arguments: {
                "topic_id" => deleted_post.topic_id,
                "selection_mode" => "post_ids",
                "post_ids" => [deleted_post.id],
              },
              request_context:,
            )
          end

        if allowed
          posts = operation.call.dig(:structuredContent, :posts)
          expect(posts.length).to eq(1), user.username
          expect(posts.first[:raw]).to eq(deleted_post.raw)
        else
          expect(&operation).to raise_error(DiscourseMcp::ToolError)
        end
      end
    end
  end

  it "supports bounded selection modes without exposing hidden or staff-only posts" do
    SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
    first_post = Fabricate(:post, user: author, raw: "first evidence")
    topic = first_post.topic
    second_post = Fabricate(:post, topic:, user: viewer, raw: "second evidence")
    hidden_post = Fabricate(:post, topic:, user: author, raw: "hidden evidence", hidden: true)
    whisper =
      Fabricate(
        :post,
        topic:,
        user: moderator,
        raw: "staff evidence",
        post_type: Post.types[:whisper],
      )
    last_post = Fabricate(:post, topic:, user: author, raw: "last evidence")
    deleted_post = Fabricate(:post, topic:, user: author, raw: "deleted evidence")
    deleted_post.trash!(admin)
    viewer_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)
    moderator_context =
      instance_double(DiscourseMcp::RequestContext, user: moderator, guardian: moderator.guardian)

    earliest =
      described_class.call(
        arguments: {
          "topic_id" => topic.id,
          "selection_mode" => "earliest",
          "limit" => 2,
        },
        request_context: viewer_context,
      ).fetch(:structuredContent)
    latest =
      described_class.call(
        arguments: {
          "topic_id" => topic.id,
          "selection_mode" => "latest",
          "limit" => 2,
        },
        request_context: viewer_context,
      ).fetch(:structuredContent)
    exact =
      described_class.call(
        arguments: {
          "topic_id" => topic.id,
          "selection_mode" => "post_ids",
          "post_ids" => [last_post.id, hidden_post.id, second_post.id],
        },
        request_context: viewer_context,
      ).fetch(:structuredContent)
    by_username =
      described_class.call(
        arguments: {
          "topic_id" => topic.id,
          "selection_mode" => "usernames",
          "usernames" => [author.username],
          "replies_only" => true,
        },
        request_context: viewer_context,
      ).fetch(:structuredContent)
    around =
      described_class.call(
        arguments: {
          "topic_id" => topic.id,
          "selection_mode" => "around_post",
          "post_number" => second_post.post_number,
          "limit" => 2,
        },
        request_context: viewer_context,
      ).fetch(:structuredContent)
    staff =
      described_class.call(
        arguments: {
          "topic_id" => topic.id,
          "selection_mode" => "post_ids",
          "post_ids" => [hidden_post.id, whisper.id, deleted_post.id],
        },
        request_context: moderator_context,
      ).fetch(:structuredContent)

    expect(earliest[:posts].pluck(:id)).to eq([first_post.id, second_post.id])
    expect(latest[:posts].pluck(:id)).to eq([second_post.id, last_post.id])
    expect(exact[:posts].pluck(:id)).to eq([last_post.id, second_post.id])
    expect(by_username[:posts].pluck(:id)).to eq([last_post.id])
    expect(around[:posts].pluck(:id)).to eq([first_post.id, second_post.id])
    expect(staff[:posts].pluck(:id)).to eq([hidden_post.id, whisper.id, deleted_post.id])
    expect(earliest[:meta]).to include(
      visible_stream_size: 3,
      selected: 2,
      returned: 2,
      exhaustive: false,
    )
  end

  it "rejects options from another selection mode" do
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)

    expect do
      described_class.call(
        arguments: {
          "topic_id" => private_post.topic_id,
          "selection_mode" => "post_ids",
          "post_ids" => [private_post.id],
          "replies_only" => false,
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.invalid_post_selection"))
  end
end

describe DiscourseMcp::Tools::GetPostReplies do
  fab!(:viewer, :user)
  fab!(:member, :user)
  fab!(:moderator)
  fab!(:admin)
  fab!(:author, :user)
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group:) }
  fab!(:private_topic) { Fabricate(:topic, category: private_category, user: author) }
  fab!(:private_post) { Fabricate(:post, topic: private_topic, user: author) }

  before { group.add(member) }

  it "reads reply relationships only when the root post is visible" do
    reply = Fabricate(:post, topic: private_topic, user: author)
    PostReply.create!(post: private_post, reply:)
    expectations = { viewer => false, moderator => false, member => true, admin => true }

    expectations.each do |user, allowed|
      request_context =
        instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
      operation =
        lambda do
          described_class.call(
            arguments: {
              "post_id" => private_post.id,
              "mode" => "reply_ids",
            },
            request_context:,
          )
        end

      if allowed
        expect(operation.call.dig(:structuredContent, :replies)).to eq([{ id: reply.id, level: 1 }])
      else
        expect(&operation).to raise_error(DiscourseMcp::ToolError)
      end
    end
  end

  it "honors the setting that removes automatic admin access to secured categories" do
    SiteSetting.suppress_secured_categories_from_admin = true
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: admin, guardian: admin.guardian)

    expect do
      described_class.call(
        arguments: {
          "post_id" => private_post.id,
          "mode" => "direct_replies",
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError)
  end

  it "reads private-message reply relationships only for participants and admins" do
    message = Fabricate(:private_message_post, user: author, recipient: member)
    reply = Fabricate(:post, topic: message.topic, user: member)
    PostReply.create!(post: message, reply:)
    expectations = { viewer => false, moderator => false, member => true, admin => true }

    expectations.each do |user, allowed|
      request_context =
        instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
      operation =
        lambda do
          described_class.call(
            arguments: {
              "post_id" => message.id,
              "mode" => "direct_replies",
            },
            request_context:,
          )
        end

      if allowed
        expect(operation.call.dig(:structuredContent, :posts).pluck(:id)).to eq([reply.id])
      else
        expect(&operation).to raise_error(DiscourseMcp::ToolError)
      end
    end
  end

  it "returns bounded direct replies and reply history without exposing hidden posts" do
    SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
    root = Fabricate(:post, user: author)
    direct_reply =
      Fabricate(:post, topic: root.topic, user: viewer, reply_to_post_number: root.post_number)
    hidden_reply = Fabricate(:post, topic: root.topic, user: author, hidden: true)
    whisper = Fabricate(:post, topic: root.topic, user: moderator, post_type: Post.types[:whisper])
    deleted_reply = Fabricate(:post, topic: root.topic, user: author)
    deleted_reply.trash!(admin)
    child_reply =
      Fabricate(
        :post,
        topic: root.topic,
        user: viewer,
        reply_to_post_number: direct_reply.post_number,
      )
    PostReply.create!(post: root, reply: direct_reply)
    PostReply.create!(post: root, reply: hidden_reply)
    PostReply.create!(post: root, reply: whisper)
    PostReply.create!(post: root, reply: deleted_reply)
    PostReply.create!(post: direct_reply, reply: child_reply)
    SiteSetting.max_reply_history = 2
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)

    ids =
      described_class.call(
        arguments: {
          "post_id" => root.id,
          "mode" => "reply_ids",
        },
        request_context:,
      ).fetch(:structuredContent)
    direct =
      described_class.call(
        arguments: {
          "post_id" => root.id,
          "mode" => "direct_replies",
          "after_post_number" => 0,
        },
        request_context:,
      ).fetch(:structuredContent)
    history =
      described_class.call(
        arguments: {
          "post_id" => child_reply.id,
          "mode" => "reply_history",
        },
        request_context:,
      ).fetch(:structuredContent)
    moderator_context =
      instance_double(DiscourseMcp::RequestContext, user: moderator, guardian: moderator.guardian)
    staff_direct =
      described_class.call(
        arguments: {
          "post_id" => root.id,
          "mode" => "direct_replies",
        },
        request_context: moderator_context,
      ).fetch(:structuredContent)

    expect(ids[:replies]).to eq(
      [{ id: direct_reply.id, level: 1 }, { id: child_reply.id, level: 2 }],
    )
    expect(ids[:meta]).to include(returned: 2, exhaustive: false)
    expect(direct[:posts].pluck(:id)).to eq([direct_reply.id])
    expect(direct[:posts].sole[:raw]).to eq(direct_reply.raw)
    expect(direct[:meta]).to include(returned: 1, page_was_full: false, upstream_limit: 20)
    expect(history[:posts].pluck(:id)).to eq([root.id, direct_reply.id])
    expect(staff_direct[:posts].pluck(:id)).to eq([direct_reply.id, hidden_reply.id, whisper.id])
    expect(staff_direct[:posts].pluck(:id)).not_to include(deleted_reply.id)
  end
end

describe DiscourseMcp::Tools::ListLatestPosts do
  fab!(:viewer, :user)
  fab!(:member, :user)
  fab!(:moderator)
  fab!(:admin)
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group:) }
  fab!(:public_post, :post)
  fab!(:private_post) { Fabricate(:post, topic: Fabricate(:topic, category: private_category)) }

  before { group.add(member) }

  it "returns only public posts visible through the caller's category access" do
    private_message = Fabricate(:private_message_post, user: viewer, recipient: member)
    expectations = {
      viewer => [public_post.id],
      moderator => [public_post.id],
      member => [private_post.id, public_post.id],
      admin => [private_post.id, public_post.id],
    }

    expectations.each do |user, expected_ids|
      request_context =
        instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
      result = described_class.call(arguments: {}, request_context:).fetch(:structuredContent)

      expect(result[:posts].pluck(:id)).to eq(expected_ids)
      expect(result[:posts].pluck(:id)).not_to include(private_message.id)
      expect(result[:posts].find { |post| post[:id] == public_post.id }[:excerpt]).to be_present
    end
  end

  it "uses a post ID cursor and applies replies-only after the fixed upstream page" do
    topic = Fabricate(:topic)
    first_post = Fabricate(:post, topic:)
    reply = Fabricate(:post, topic:)
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)

    result =
      described_class.call(
        arguments: {
          "before_post_id" => reply.id + 1,
          "replies_only" => true,
        },
        request_context:,
      ).fetch(:structuredContent)

    expect(result[:posts].pluck(:id)).to include(reply.id)
    expect(result[:posts].pluck(:id)).not_to include(first_post.id)
    expect(result[:meta]).to include(
      before_post_id: reply.id + 1,
      upstream_page_size: 50,
      replies_only_projection: true,
      next_before_post_id: public_post.id,
    )
  end

  it "honors the setting that removes automatic admin access to secured categories" do
    SiteSetting.suppress_secured_categories_from_admin = true
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: admin, guardian: admin.guardian)

    result = described_class.call(arguments: {}, request_context:).fetch(:structuredContent)

    expect(result[:posts].pluck(:id)).to eq([public_post.id])
  end
end

describe DiscourseMcp::Tools::GetTopicViewStats do
  fab!(:viewer, :user)
  fab!(:member, :user)
  fab!(:moderator)
  fab!(:admin)
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group:) }
  fab!(:topic) { Fabricate(:topic, category: private_category) }

  before { group.add(member) }

  it "returns ascending daily totals only to callers who can see the topic" do
    first = Fabricate(:topic_view_stat, topic:, viewed_at: 2.days.ago, anonymous_views: 2)
    second = Fabricate(:topic_view_stat, topic:, viewed_at: 1.day.ago, logged_in_views: 3)
    expectations = { viewer => false, moderator => false, member => true, admin => true }

    expectations.each do |user, allowed|
      request_context =
        instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
      operation =
        lambda { described_class.call(arguments: { "topic_id" => topic.id }, request_context:) }

      if allowed
        result = operation.call.fetch(:structuredContent)
        expect(result[:view_stats]).to eq(
          [
            { viewed_at: first.viewed_at.to_date.iso8601, views: 3 },
            { viewed_at: second.viewed_at.to_date.iso8601, views: 4 },
          ],
        )
        expect(result[:meta]).to include(default_range_days: 30, returned: 2)
      else
        expect(&operation).to raise_error(DiscourseMcp::ToolError)
      end
    end
  end

  it "validates and applies an explicit date range" do
    included = Fabricate(:topic_view_stat, topic:, viewed_at: 3.days.ago)
    Fabricate(:topic_view_stat, topic:, viewed_at: 10.days.ago)
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: member, guardian: member.guardian)

    result =
      described_class.call(
        arguments: {
          "topic_id" => topic.id,
          "from" => 5.days.ago.to_date.iso8601,
          "to" => Date.current.iso8601,
        },
        request_context:,
      ).fetch(:structuredContent)

    expect(result[:view_stats].sole[:viewed_at]).to eq(included.viewed_at.to_date.iso8601)
    expect(result[:meta][:default_range_days]).to be_nil
    expect do
      described_class.call(
        arguments: {
          "topic_id" => topic.id,
          "from" => "not-a-date",
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError)
  end

  it "honors the setting that removes automatic admin access to secured categories" do
    SiteSetting.suppress_secured_categories_from_admin = true
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: admin, guardian: admin.guardian)

    expect do
      described_class.call(arguments: { "topic_id" => topic.id }, request_context:)
    end.to raise_error(DiscourseMcp::ToolError)
  end

  it "returns private-message stats only to participants and admins" do
    author = Fabricate(:user)
    message = Fabricate(:private_message_post, user: author, recipient: member)
    Fabricate(:topic_view_stat, topic: message.topic)
    expectations = { viewer => false, moderator => false, member => true, admin => true }

    expectations.each do |user, allowed|
      request_context =
        instance_double(DiscourseMcp::RequestContext, user:, guardian: user.guardian)
      operation =
        lambda do
          described_class.call(arguments: { "topic_id" => message.topic_id }, request_context:)
        end

      if allowed
        expect(operation.call.dig(:structuredContent, :view_stats).length).to eq(1)
      else
        expect(&operation).to raise_error(DiscourseMcp::ToolError)
      end
    end
  end
end

describe DiscourseMcp::Tools::ListDirectoryItems do
  fab!(:viewer, :user)
  fab!(:member, :user)
  fab!(:target, :user)
  fab!(:group) do
    Fabricate(
      :group,
      members_visibility_level: Group.visibility_levels[:members],
      users: [member, target],
    )
  end

  before do
    DirectoryItem.create!(
      period_type: DirectoryItem.period_types[:all],
      user: target,
      likes_received: 7,
      likes_given: 6,
      topics_entered: 5,
      days_visited: 4,
      posts_read: 3,
      topic_count: 2,
      post_count: 1,
    )
  end

  it "returns bounded directory metrics and truthful continuation" do
    target.user_stat.update!(time_read: 120)
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)

    result =
      described_class.call(
        arguments: {
          "period" => "all",
          "username" => target.username,
          "limit" => 1,
        },
        request_context:,
      ).fetch(:structuredContent)

    expect(result[:directory_items].sole).to include(
      id: target.id,
      likes_received: 7,
      post_count: 1,
      time_read: 120,
    )
    expect(result.dig(:directory_items, 0, :user, :username)).to eq(target.username)
    expect(result[:meta]).to include(page: 0, limit: 1, returned: 1, total: 1, has_more: false)
  end

  it "orders by a public user field and reports the next page" do
    other_user = Fabricate(:user)
    DirectoryItem.create!(
      period_type: DirectoryItem.period_types[:all],
      user: other_user,
      likes_received: 0,
      likes_given: 0,
      topics_entered: 0,
      days_visited: 0,
      posts_read: 0,
      topic_count: 0,
      post_count: 0,
    )
    user_field = Fabricate(:user_field, name: "rank_field", show_on_profile: true)
    UserCustomField.create!(
      user: target,
      name: "#{User::USER_FIELD_PREFIX}#{user_field.id}",
      value: "zulu",
    )
    UserCustomField.create!(
      user: other_user,
      name: "#{User::USER_FIELD_PREFIX}#{user_field.id}",
      value: "alpha",
    )
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)

    result =
      described_class.call(
        arguments: {
          "period" => "all",
          "order" => user_field.name,
          "ascending" => true,
          "limit" => 1,
        },
        request_context:,
      ).fetch(:structuredContent)

    expect(result[:directory_items].sole[:id]).to eq(other_user.id)
    expect(result[:meta]).to include(total: 2, has_more: true, next_page: 1)
  end

  it "requires access to a requested group's membership list" do
    denied_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)
    allowed_context =
      instance_double(DiscourseMcp::RequestContext, user: member, guardian: member.guardian)

    expect do
      described_class.call(
        arguments: {
          "period" => "all",
          "group" => group.name,
        },
        request_context: denied_context,
      )
    end.to raise_error(DiscourseMcp::ToolError)

    result =
      described_class.call(
        arguments: {
          "period" => "all",
          "group" => group.name,
        },
        request_context: allowed_context,
      )
    expect(result.dig(:structuredContent, :directory_items).pluck(:id)).to eq([target.id])
  end

  it "ignores exclusions for groups whose membership is not visible to the caller" do
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)

    result =
      described_class.call(
        arguments: {
          "period" => "all",
          "exclude_groups" => [group.name],
        },
        request_context:,
      )

    expect(result.dig(:structuredContent, :directory_items).pluck(:id)).to eq([target.id])
  end

  it "is unavailable when the user directory is disabled" do
    SiteSetting.enable_user_directory = false
    request_context =
      instance_double(DiscourseMcp::RequestContext, user: viewer, guardian: viewer.guardian)

    expect do
      described_class.call(arguments: { "period" => "all" }, request_context:)
    end.to raise_error(DiscourseMcp::ToolError)
  end
end

describe DiscourseMcp::Tools::GetDraft do
  fab!(:user)
  fab!(:other_user, :user)

  let(:request_context) { instance_double(DiscourseMcp::RequestContext, user:) }

  it "returns the authenticated user's draft in the compatibility format" do
    draft_data = {
      title: "A topic",
      reply: "A draft reply",
      categoryId: 4,
      tags: ["support"],
      action: "createTopic",
    }.to_json
    Draft.set(user, Draft::NEW_TOPIC, 0, draft_data)
    Draft.set(other_user, Draft::NEW_TOPIC, 0, { reply: "Private draft" }.to_json)

    result = described_class.call(arguments: { "draft_key" => Draft::NEW_TOPIC }, request_context:)

    expect(result.dig(:structuredContent)).to eq(
      draft_key: Draft::NEW_TOPIC,
      sequence: 0,
      found: true,
      data: {
        title: "A topic",
        reply: "A draft reply",
        category_id: 4,
        tags: ["support"],
        action: "createTopic",
      },
    )
  end

  it "reports a missing draft without returning another user's draft" do
    Draft.set(other_user, "topic_123", 0, { reply: "Private draft" }.to_json)

    result = described_class.call(arguments: { "draft_key" => "topic_123" }, request_context:)

    expect(result.dig(:structuredContent)).to eq(draft_key: "topic_123", found: false)
  end

  it "rejects a stale sequence" do
    sequence = Draft.set(user, Draft::NEW_TOPIC, 0, { reply: "First version" }.to_json)
    Draft.set(user, Draft::NEW_TOPIC, sequence, { reply: "Second version" }.to_json)

    expect do
      described_class.call(
        arguments: {
          "draft_key" => Draft::NEW_TOPIC,
          "sequence" => 0,
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_sequence_conflict"))
  end
end

describe DiscourseMcp::Tools::SaveDraft do
  fab!(:user)
  fab!(:topic)

  let(:request_context) { instance_double(DiscourseMcp::RequestContext, user:) }

  it "creates and updates a topic reply draft" do
    draft_key = "topic_#{topic.id}"
    created =
      described_class.call(
        arguments: {
          "draft_key" => draft_key,
          "reply" => "First version",
          "tags" => ["support"],
        },
        request_context:,
      )

    expect(created.dig(:structuredContent)).to eq(draft_key:, sequence: 0, saved: true)
    expect(Draft.find_by!(user:, draft_key:).parsed_data).to include(
      "reply" => "First version",
      "action" => "reply",
      "topic_id" => topic.id,
      "tags" => ["support"],
    )

    updated =
      described_class.call(
        arguments: {
          "draft_key" => draft_key,
          "reply" => "Second version",
          "sequence" => 0,
        },
        request_context:,
      )

    expect(updated.dig(:structuredContent)).to eq(draft_key:, sequence: 1, saved: true)
    expect(Draft.find_by!(user:, draft_key:).parsed_data["reply"]).to eq("Second version")
  end

  it "rejects a stale sequence" do
    Draft.set(user, Draft::NEW_TOPIC, 0, { reply: "First version" }.to_json)
    Draft.set(user, Draft::NEW_TOPIC, 0, { reply: "Second version" }.to_json)

    expect do
      described_class.call(
        arguments: {
          "draft_key" => Draft::NEW_TOPIC,
          "reply" => "Stale version",
          "sequence" => 0,
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_sequence_conflict"))
  end

  it "enforces the site's maximum draft length" do
    SiteSetting.max_draft_length = 20

    expect do
      described_class.call(
        arguments: {
          "draft_key" => Draft::NEW_TOPIC,
          "reply" => "This draft is too long",
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_too_long"))
  end

  it "enforces the maximum number of drafts per user" do
    SiteSetting.max_drafts_per_user = 1
    Draft.set(user, Draft::NEW_TOPIC, 0, { reply: "Existing draft" }.to_json)

    expect do
      described_class.call(
        arguments: {
          "draft_key" => "topic_#{topic.id}",
          "reply" => "Another draft",
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("draft.too_many_drafts.title"))
  end
end

describe DiscourseMcp::Tools::DeleteDraft do
  fab!(:user)

  let(:request_context) { instance_double(DiscourseMcp::RequestContext, user:) }

  it "deletes only the draft at the current sequence" do
    sequence = Draft.set(user, Draft::NEW_TOPIC, 0, { reply: "First version" }.to_json)
    sequence = Draft.set(user, Draft::NEW_TOPIC, sequence, { reply: "Second version" }.to_json)

    expect do
      described_class.call(
        arguments: {
          "draft_key" => Draft::NEW_TOPIC,
          "sequence" => sequence - 1,
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.draft_sequence_conflict"))

    result =
      described_class.call(
        arguments: {
          "draft_key" => Draft::NEW_TOPIC,
          "sequence" => sequence,
        },
        request_context:,
      )

    expect(result.dig(:structuredContent)).to eq(draft_key: Draft::NEW_TOPIC, deleted: true)
    expect(Draft.find_by(user:, draft_key: Draft::NEW_TOPIC)).to be_nil
  end
end

describe DiscourseMcp::Tools::ListUserPosts do
  fab!(:viewer, :user)
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, user:) }

  let(:request_context) { instance_double(DiscourseMcp::RequestContext, guardian: viewer.guardian) }

  it "returns a permission-aware page of the user's topics and replies" do
    first_post = Fabricate(:post, topic:, user:, raw: "First post", created_at: 2.minutes.ago)
    second_post = Fabricate(:post, topic:, user:, raw: "Second post", created_at: 1.minute.ago)
    [first_post, second_post].each do |post|
      UserAction.create!(
        action_type: UserAction::REPLY,
        user:,
        acting_user: user,
        target_topic: topic,
        target_post: post,
        created_at: post.created_at,
      )
    end

    private_category = Fabricate(:private_category, group: Fabricate(:group))
    private_topic = Fabricate(:topic, user:, category: private_category)
    private_post = Fabricate(:post, topic: private_topic, user:, raw: "Private post")
    UserAction.create!(
      action_type: UserAction::REPLY,
      user:,
      acting_user: user,
      target_topic: private_topic,
      target_post: private_post,
    )

    deleted_post = Fabricate(:post, topic:, user:, raw: "Deleted post")
    deleted_post.trash!
    UserAction.create!(
      action_type: UserAction::REPLY,
      user:,
      acting_user: user,
      target_topic: topic,
      target_post: deleted_post,
    )

    result =
      described_class.call(
        arguments: {
          "username" => user.username,
          "page" => 0,
          "limit" => 1,
        },
        request_context:,
      )

    expect(result.dig(:structuredContent, :posts).sole).to include(
      id: second_post.id,
      topic_id: topic.id,
      post_number: second_post.post_number,
      title: topic.title,
      category_id: topic.category_id,
    )
    expect(result.dig(:structuredContent, :meta)).to eq(page: 0, limit: 1, has_more: true)
  end

  it "does not expose activity for a hidden profile" do
    SiteSetting.allow_users_to_hide_profile = true
    user.user_option.update!(hide_profile: true)

    expect do
      described_class.call(arguments: { "username" => user.username }, request_context:)
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.user_not_found"))
  end
end

describe DiscourseMcp::Tools::GetUserSummary do
  fab!(:viewer, :user)
  fab!(:user)

  let(:request_context) { instance_double(DiscourseMcp::RequestContext, guardian: viewer.guardian) }

  it "returns profile-visible summary metrics without private bookmark counts" do
    user.user_stat.update!(post_count: 3, topic_count: 2, days_visited: 7)

    result = described_class.call(arguments: { "username" => user.username }, request_context:)

    expect(result.dig(:structuredContent)).to include(
      username: user.username,
      post_count: 3,
      topic_count: 2,
      days_visited: 7,
      bookmark_count: nil,
      top_topics: [],
      top_replies: [],
    )
  end

  it "does not expose a hidden user's summary" do
    SiteSetting.allow_users_to_hide_profile = true
    user.user_option.update!(hide_profile: true)

    expect do
      described_class.call(arguments: { "username" => user.username }, request_context:)
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.user_not_found"))
  end
end

describe DiscourseMcp::Tools::ListUserActions do
  fab!(:viewer, :user)
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, user:) }
  fab!(:post) { Fabricate(:post, topic:, user:, raw: "Visible reply") }

  let(:request_context) { instance_double(DiscourseMcp::RequestContext, guardian: viewer.guardian) }

  before do
    user.user_stat.update!(post_count: 1)
    UserAction.create!(
      action_type: UserAction::REPLY,
      user:,
      acting_user: user,
      target_topic: topic,
      target_post: post,
    )
    UserAction.create!(
      action_type: UserAction::RESPONSE,
      user:,
      acting_user: user,
      target_topic: topic,
      target_post: post,
    )
  end

  it "returns named public actions and omits private action types for another user" do
    result = described_class.call(arguments: { "username" => user.username }, request_context:)

    expect(result.dig(:structuredContent, :actions).sole).to include(
      action_type: "replies",
      action_type_id: UserAction::REPLY,
      post_id: post.id,
      topic_id: topic.id,
    )
  end

  it "rejects a request for another user's private action types" do
    expect do
      described_class.call(
        arguments: {
          "username" => user.username,
          "action_types" => ["responses"],
        },
        request_context:,
      )
    end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.user_not_found"))
  end
end
