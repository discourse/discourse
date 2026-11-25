# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with unit four MCP writes"

  before { SiteSetting.unique_posts_mins = 0 }

  def review4_state
    {
      posts: Post.with_deleted.order(:id).pluck(:id, :topic_id, :raw, :cooked, :deleted_at),
      topics: Topic.with_deleted.order(:id).pluck(:id, :title, :category_id, :deleted_at),
      topic_tags: TopicTag.order(:topic_id, :tag_id).pluck(:topic_id, :tag_id),
      tags: Tag.order(:id).pluck(:id, :name),
      reviewables: Reviewable.order(:id).pluck(:id, :status, :topic_id, :target_id, :payload),
    }
  end

  def review4_queue(tags:, raw: McpContentRestrictionsUnit4::PROSE, author: admin)
    Fabricate(
      :reviewable_queued_post_topic,
      category: allowed_category,
      target_created_by: author,
      payload: {
        title: "Review four seasonal garden observations",
        raw:,
        tags:,
        archetype: "regular",
      },
    )
  end

  def review4_approve(reviewable, access_token: token)
    rpc(
      "discourse_perform_reviewable_action",
      { reviewable_id: reviewable.id, action_id: "approve_post", confirm: true },
      access_token:,
    )
  end

  def review4_category_tags
    SiteSetting.max_tags_per_topic = 2
    kept = Fabricate(:tag, id: 112_840_010, name: "reviewfourkept")
    filtered = Fabricate(:tag, id: 112_840_011, name: "reviewfourfiltered")
    watched = Fabricate(:tag, id: 112_840_012, name: "reviewfourallowedwatched")
    denied = Fabricate(:tag, id: 112_840_013, name: "reviewfourzdenied")
    allowed_category.update!(allow_global_tags: false)
    allowed_category.tags = [kept, denied, watched]
    restricted_category.tags = [filtered]
    { "reviewfourdeniedword" => denied, "reviewfourallowedword" => watched }.each do |word, tag|
      Fabricate(:watched_word, action: WatchedWord.actions[:tag], word:, replacement: tag.name)
    end
    [kept, filtered, watched, denied]
  end

  def review4_category_rule(denied)
    McpContentRule.create!(
      rule_kind: "forum_content",
      config: {
        allow: {
          mode: "all",
          category_ids: [],
          tag_ids: [],
        },
        deny: {
          category_ids: [restricted_category.id],
          tag_ids: [denied.id],
        },
      },
    )
  end

  def review4_reviewer
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
    membership = Fabricate(:group_user)
    reviewer = membership.user
    Fabricate(:category_moderation_group, category: allowed_category, group: membership.group)
    expect(reviewer.staff?).to eq(false)
    expect(reviewer.guardian.can_tag_topics?).to eq(false)
    expect(recipient.guardian.can_tag_topics?).to eq(false)
    issue_token(reviewer)
  end

  %i[create_topic queued_approval].each do |writer|
    it "[cr-u4] refuses #{writer} after category filtering frees a denied watched-tag slot without persisting content" do
      kept, filtered, _watched, denied = review4_category_tags
      raw = "Seasonal reviewfourdeniedword garden observations."
      args = topic_arguments(tags: [kept.name, filtered.name], raw:)
      reviewable = review4_queue(tags: args[:tags], raw:) if writer == :queued_approval
      write = -> do
        if reviewable
          review4_approve(reviewable)
        else
          rpc("discourse_create_topic", args)
        end
      end
      isolated do
        data = expect_success(write.call)
        topic = reviewable ? reviewable.reload.target.topic : Topic.find(data.fetch("topic_id"))
        expect(topic.tags).to contain_exactly(kept, denied)
        expect(topic.posts.sole.raw).to eq(raw)
      end
      reviewable&.reload
      review4_category_rule(denied)
      expected =
        if reviewable
          reference_error
        else
          rpc(
            "discourse_create_topic",
            args.except(:tags).merge(category_id: McpContentRestrictionsUnit4::MISSING_ID),
          )
        end
      expect_refusal(expected)
      before_state = review4_state
      response = write.call
      aggregate_failures do
        expect_refusal(response)
        expect(response).to eq(expected), "CATEGORY FILTER: refusal envelope changed"
        expect(review4_state).to eq(before_state),
        "CATEGORY FILTER ATOMICITY: topic, post or tags persisted"
      end
    end

    it "[cr-u4] persists allowed #{writer} after category filtering frees an allowed watched-tag slot" do
      kept, filtered, watched, denied = review4_category_tags
      raw = "Seasonal reviewfourallowedword garden observations."
      review4_category_rule(denied)
      if writer == :queued_approval
        reviewable = review4_queue(tags: [kept.name, filtered.name], raw:)
        expect_success(review4_approve(reviewable))
        expect(reviewable.reload.status).to eq("approved")
        topic = reviewable.target.topic
      else
        data =
          expect_success(
            rpc("discourse_create_topic", topic_arguments(tags: [kept.name, filtered.name], raw:)),
          )
        topic = Topic.find(data.fetch("topic_id"))
      end
      expect(topic.tags).to contain_exactly(kept, watched)
      expect(topic.posts.sole.raw).to eq(raw)
    end
  end

  %i[string object].each do |shape|
    it "[cr-u4] refuses non-staff approval of a non-tagging author's #{shape} payload tags without persisting content" do
      reviewer_token = review4_reviewer
      entry = shape == :object ? { "name" => denied_tag.name } : " #{denied_tag.name} "
      reviewable = review4_queue(tags: [entry], author: recipient)
      expect(reviewer_token.user.guardian.can_see_review_queue?).to eq(true)
      isolated do
        expect_success(review4_approve(reviewable, access_token: reviewer_token))
        expect(reviewable.reload.status).to eq("approved")
        expect(reviewable.target.topic.tags).to contain_exactly(denied_tag)
      end
      reviewable.reload
      activate!
      expected = reference_error
      before_state = review4_state
      response = review4_approve(reviewable, access_token: reviewer_token)
      aggregate_failures do
        expect_refusal(response)
        expect(response).to eq(expected), "QUEUED FALLBACK: refusal envelope changed"
        expect(review4_state).to eq(before_state),
        "QUEUED FALLBACK ATOMICITY: topic, post, tags or approval persisted"
      end
    end

    it "[cr-u4] persists non-staff approval of a non-tagging author's allowed #{shape} payload tags" do
      reviewer_token = review4_reviewer
      allowed = Fabricate(:tag, id: 112_840_020, name: "reviewfourfallback")
      entry = shape == :object ? { "name" => allowed.name } : " #{allowed.name} "
      reviewable = review4_queue(tags: [entry], author: recipient)
      expect(reviewer_token.user.guardian.can_see_review_queue?).to eq(true)
      activate!
      expect_success(review4_approve(reviewable, access_token: reviewer_token))
      expect(reviewable.reload.status).to eq("approved")
      expect(reviewable.target.topic.tags).to contain_exactly(allowed)
      expect(reviewable.target.reload.raw).to eq(reviewable.payload.fetch("raw"))
    end
  end

  it "[cr-u4] refuses a denied watched-tag private message atomically and persists an allowed watched-tag private message" do
    allowed = Fabricate(:tag, id: 112_840_030, name: "reviewfourpmallowed")
    { "reviewfourpmdenied" => denied_tag, "reviewfourpmallowed" => allowed }.each do |word, tag|
      Fabricate(:watched_word, action: WatchedWord.actions[:tag], word:, replacement: tag.name)
    end
    args = {
      usernames: [recipient.username],
      title: "Review four private seasonal garden observations",
      raw: "Seasonal reviewfourpmdenied garden observations.",
    }
    isolated do
      data = expect_success(rpc("discourse_create_private_message", args))
      topic = Topic.find(data.fetch("topic_id"))
      expect(topic.category_id).to be_nil
      expect(topic.tags).to contain_exactly(denied_tag)
    end
    activate!
    data =
      expect_success(
        rpc(
          "discourse_create_private_message",
          args.merge(raw: "Seasonal reviewfourpmallowed garden observations."),
        ),
      )
    allowed_post = Post.find(data.fetch("id"))
    expect(allowed_post.topic.private_message?).to eq(true)
    expect(allowed_post.topic.tags).to contain_exactly(allowed)
    expect(allowed_post.raw).to include("reviewfourpmallowed")
    expected = reference_error
    before_state = review4_state
    response = rpc("discourse_create_private_message", args)
    aggregate_failures do
      expect_refusal(response)
      expect(response).to eq(expected)
      expect(review4_state).to eq(before_state)
    end
  end

  %i[percent_encoded trailing_dot uppercase unicode_site punycode_site].each do |shape|
    it "[cr-u4] refuses a labelled #{shape} host link to this site without persisting content" do
      host =
        case shape
        when :unicode_site
          "bücher.example"
        when :punycode_site
          "xn--bcher-kva.example"
        else
          "review-four-site.example"
        end
      Discourse.stubs(:current_hostname).returns(
        shape == :unicode_site ? "review-four-site.example" : host,
      )
      Discourse.stubs(:base_url).returns("https://#{host}")
      destination = Fabricate(:topic, id: 112_840_101, category: restricted_category)
      link_host =
        case shape
        when :percent_encoded
          "review-four-s%69te.example"
        when :trailing_dot
          "#{host}."
        when :uppercase
          host.upcase
        when :unicode_site
          "xn--bcher-kva.example"
        else
          "bücher.example"
        end
      href = "https://#{link_host}/t/secret/#{destination.id}"
      args = topic_arguments(raw: "Read [garden notes](#{href}) for seasonal observations.")
      isolated do
        data = expect_success(rpc("discourse_create_topic", args))
        anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a")
        expect(anchor.text).to eq("garden notes")
        expected_host = shape == :punycode_site ? host : link_host
        expect(anchor["href"]).to eq("https://#{expected_host}/t/secret/#{destination.id}")
      end
      activate!
      control =
        expect_success(
          rpc(
            "discourse_create_topic",
            topic_arguments(
              title: "Permitted review four external garden references",
              raw: McpContentRestrictionsUnit4::LABELLED_LINK,
            ),
          ),
        )
      expect(Post.find(control.fetch("id")).raw).to eq(McpContentRestrictionsUnit4::LABELLED_LINK)
      expected = reference_error
      before_state = review4_state
      response = rpc("discourse_create_topic", args)
      aggregate_failures do
        expect_refusal(response)
        expect(response).to eq(expected), "INTERNAL HOST: labelled link was accepted"
        expect(review4_state).to eq(before_state),
        "INTERNAL HOST ATOMICITY: linked content persisted"
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
