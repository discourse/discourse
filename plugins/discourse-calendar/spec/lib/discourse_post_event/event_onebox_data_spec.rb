# frozen_string_literal: true

describe DiscoursePostEvent::EventOneboxData do
  fab!(:author, :user) { Fabricate(:user, admin: true) }
  fab!(:reader, :user)

  before do
    freeze_time Time.utc(2018, 6, 5, 18, 40)
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  def link_to(post, target_topic)
    post.update!(raw: "see #{target_topic.url}")
    TopicLink.extract_from(post)
    post
  end

  # a self-onebox (a reply linking the topic it's in) produces no TopicLink row,
  # so we craft the cooked aside the way the onebox would
  def with_self_onebox(post, topic, extra = "")
    post.update_columns(
      cooked:
        "<aside class=\"quote\" data-post=\"1\" data-topic=\"#{topic.id}\"#{extra}><blockquote>x</blockquote></aside>",
    )
    post
  end

  it "returns the serialized event keyed by source post and linked topic id" do
    event_post = create_post_with_event(author, 'name="Pancakes"')
    linking_post = link_to(Fabricate(:post), event_post.topic)

    result = described_class.build(posts: [linking_post], guardian: Guardian.new(reader))

    expect(result.keys).to eq([linking_post.id])
    event = result[linking_post.id][event_post.topic_id]
    expect(event).to be_present
    expect(event[:name]).to eq("Pancakes")
    expect(event[:starts_at]).to be_present
  end

  it "ignores links to non-event topics" do
    linking_post = link_to(Fabricate(:post), Fabricate(:post).topic)

    result = described_class.build(posts: [linking_post], guardian: Guardian.new(reader))

    expect(result).to be_empty
  end

  it "omits events the reader cannot see" do
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    event_post =
      create_post_with_event(author).tap { |p| p.topic.update!(category: private_category) }
    linking_post = link_to(Fabricate(:post), event_post.topic)

    result = described_class.build(posts: [linking_post], guardian: Guardian.new(reader))

    expect(result).to be_empty
  end

  it "returns nothing without posts" do
    expect(described_class.build(posts: [], guardian: Guardian.new(reader))).to eq({})
  end

  context "with a same-topic onebox (a reply linking the event topic it's in)" do
    it "includes the event keyed by the topic id" do
      event_post = create_post_with_event(author, 'name="Pancakes"')
      reply = with_self_onebox(Fabricate(:post, topic: event_post.topic), event_post.topic)

      result = described_class.build(posts: [reply], guardian: Guardian.new(reader))

      expect(result[reply.id][event_post.topic_id]).to be_present
    end

    it "ignores a same-topic quote (which carries a data-username)" do
      event_post = create_post_with_event(author)
      reply =
        with_self_onebox(
          Fabricate(:post, topic: event_post.topic),
          event_post.topic,
          ' data-username="bob"',
        )

      result = described_class.build(posts: [reply], guardian: Guardian.new(reader))

      expect(result).to be_empty
    end

    it "does nothing for a self-link in a non-event topic" do
      topic = Fabricate(:topic)
      reply = with_self_onebox(Fabricate(:post, topic: topic), topic)

      result = described_class.build(posts: [reply], guardian: Guardian.new(reader))

      expect(result).to be_empty
    end
  end

  describe "delivered through the post serializer" do
    it "preloads event_oneboxes onto posts in a topic view" do
      event_post = create_post_with_event(author, 'name="Pancakes"')
      linking_post = link_to(Fabricate(:post), event_post.topic)

      topic_view = TopicView.new(linking_post.topic_id, reader)
      serializer = PostSerializer.new(linking_post, scope: Guardian.new(reader), root: false)
      serializer.topic_view = topic_view
      json = serializer.as_json

      expect(json[:event_oneboxes]).to be_present
      expect(json[:event_oneboxes][event_post.topic_id]).to be_present
    end

    it "computes event_oneboxes on demand when serialized without a topic view" do
      # mirrors a freshly cooked-post-processed post (message bus update): the
      # fallback only pays its queries once the cooked onebox markup is present
      event_post = create_post_with_event(author, 'name="Pancakes"')
      linking_post = link_to(Fabricate(:post), event_post.topic)
      linking_post.update_columns(
        cooked:
          "<aside class=\"quote\" data-topic=\"#{event_post.topic_id}\" data-post=\"1\"><blockquote>x</blockquote></aside>",
      )

      json = PostSerializer.new(linking_post, scope: Guardian.new(reader), root: false).as_json

      expect(json[:event_oneboxes]).to be_present
      expect(json[:event_oneboxes][event_post.topic_id]).to be_present
    end

    it "skips the on-demand computation when cooked has no onebox markup" do
      event_post = create_post_with_event(author)
      linking_post = link_to(Fabricate(:post), event_post.topic)

      queries =
        track_sql_queries do
          json = PostSerializer.new(linking_post, scope: Guardian.new(reader), root: false).as_json
          expect(json).not_to have_key(:event_oneboxes)
        end

      expect(queries).not_to include(match(/topic_links/))
    end

    it "omits event_oneboxes for a post that links nothing" do
      json = PostSerializer.new(Fabricate(:post), scope: Guardian.new(reader), root: false).as_json

      expect(json).not_to have_key(:event_oneboxes)
    end
  end
end
