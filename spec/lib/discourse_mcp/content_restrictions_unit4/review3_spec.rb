# frozen_string_literal: true

require_relative "support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with unit four MCP writes"

  def review3_upload
    data =
      expect_success(
        rpc(
          "discourse_upload_file",
          {
            upload_type: "composer",
            filename: "review-three-garden.txt",
            image_data: Base64.strict_encode64("Notes about seasonal gardens"),
          },
        ),
      )
    Upload.find(data.fetch("id"))
  end

  def review3_queue(tags, author: admin)
    Fabricate(
      :reviewable_queued_post_topic,
      category: allowed_category,
      target_created_by: author,
      payload: {
        raw: McpContentRestrictionsUnit4::PROSE,
        title: "Queued seasonal garden observations",
        tags: tags,
        archetype: "regular",
      },
    )
  end

  %w[../../../ %2e%2e/%2e%2e/%2e%2e/].each do |traversal|
    %i[href pair original matching_pair].each do |shape|
      it "[cr-u4] refuses short-url trailing traversal #{traversal} in #{shape}" do
        activate!
        upload = review3_upload
        destination = Fabricate(:topic, id: 111_730_001, category: restricted_category)
        traversing_path = "#{upload.short_path}/#{traversal}t/#{destination.id}"
        href = shape == :original ? upload.short_path : traversing_path
        original =
          case shape
          when :pair
            upload.short_url
          when :original, :matching_pair
            traversing_path
          end
        attribute = original ? " data-orig-href=\"#{original}\"" : ""
        raw = "Read <a class=\"attachment\" href=\"#{href}\"#{attribute}>garden notes</a>."
        args = topic_arguments(raw:)
        isolated do
          McpContentRule.delete_all
          data = expect_success(rpc("discourse_create_topic", args))
          anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a")
          expect(anchor["href"]).to eq(href)
          expect(anchor["data-orig-href"]).to eq(original)
          expect(URI.join(Discourse.base_url, CGI.unescape(traversing_path)).normalize.path).to eq(
            "/t/#{destination.id}",
          )
        end
        assert_reference_write("discourse_create_topic", args)
      end
    end
  end

  %w[mention mention-group].each do |css_class|
    it "[cr-u4] refuses #{css_class} anchors carrying an ungranted upload in data-orig-href" do
      group = Fabricate(:group, name: "reviewthreegardeners")
      name = css_class == "mention" ? recipient.username.downcase : group.name
      prefix = css_class == "mention" ? "u" : "groups"
      upload = Fabricate(:upload, id: 111_730_002, user: recipient)
      raw =
        "Ask <a class=\"#{css_class}\" href=\"/#{prefix}/#{name}\" data-orig-href=\"#{upload.url}\">@#{name}</a> about gardens."
      args = topic_arguments(raw:)
      isolated do
        data = expect_success(rpc("discourse_create_topic", args))
        anchor = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked).at_css("a")
        expect(anchor["data-orig-href"]).to eq(upload.url)
        expect(anchor["href"]).to eq("/#{prefix}/#{name}")
      end
      activate!
      assert_reference_write("discourse_create_topic", args)
    end
  end

  it "[cr-u4] judges watched-word tags after synonymous input tags collapse under the tag limit" do
    SiteSetting.max_tags_per_topic = 2
    target = Fabricate(:tag, id: 111_730_010, name: "reviewthreeflowers")
    aliases =
      [11, 12].map do |offset|
        Fabricate(
          :tag,
          id: 111_730_000 + offset,
          name: "reviewthreealias#{offset}",
          target_tag: target,
        )
      end
    watched = Fabricate(:tag, id: 111_730_013, name: "reviewthreewatched", target_tag: denied_tag)
    Fabricate(
      :watched_word,
      action: WatchedWord.actions[:tag],
      word: "reviewthreegardenspecial",
      replacement: watched.name,
    )
    args =
      topic_arguments(tags: aliases.map(&:name), raw: "Seasonal reviewthreegardenspecial gardens.")
    isolated do
      data = expect_success(rpc("discourse_create_topic", args))
      expect(Topic.find(data.fetch("topic_id")).tags).to contain_exactly(target, denied_tag)
    end
    activate!
    missing =
      rpc(
        "discourse_create_topic",
        args.merge(category_id: McpContentRestrictionsUnit4::MISSING_ID),
      )
    before_state = content_state
    response = rpc("discourse_create_topic", args)
    aggregate_failures do
      expect_refusal(response)
      expect(response).to eq(missing)
      expect(content_state).to eq(before_state),
      "PROSPECTIVE ATOMICITY: denied watched tag persisted"
    end
  end

  it "[cr-u4] judges category-reviewer approval by the queued author's child and mandatory parent tags" do
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
    membership = Fabricate(:group_user)
    reviewer = membership.user
    Fabricate(:category_moderation_group, category: allowed_category, group: membership.group)
    reviewer_token = issue_token(reviewer)
    child = Fabricate(:tag, id: 111_730_020, name: "reviewthreechild")
    Fabricate(:tag_group, parent_tag: denied_tag, tags: [child])
    reviewable = review3_queue([child.name])
    args = { reviewable_id: reviewable.id, action_id: "approve_post", confirm: true }
    expect(reviewer.staff?).to eq(false)
    expect(reviewer.guardian.can_see_review_queue?).to eq(true)
    expect(reviewer.guardian.can_tag_topics?).to eq(false)
    expect(admin.guardian.can_tag_topics?).to eq(true)
    isolated do
      expect_success(rpc("discourse_perform_reviewable_action", args, access_token: reviewer_token))
      expect(reviewable.reload.status).to eq("approved")
      expect(reviewable.target.topic.tags).to contain_exactly(child, denied_tag)
    end
    reviewable.reload
    activate!
    allowed_parent = Fabricate(:tag, id: 111_730_021, name: "reviewthreeallowedparent")
    allowed_child = Fabricate(:tag, id: 111_730_022, name: "reviewthreeallowedchild")
    Fabricate(:tag_group, parent_tag: allowed_parent, tags: [allowed_child])
    control = review3_queue([allowed_child.name])
    expect_success(
      rpc(
        "discourse_perform_reviewable_action",
        { reviewable_id: control.id, action_id: "approve_post", confirm: true },
        access_token: reviewer_token,
      ),
    )
    expect(control.reload.status).to eq("approved")
    expect(control.target.topic.tags).to contain_exactly(allowed_child, allowed_parent)
    before_state = content_state
    response = rpc("discourse_perform_reviewable_action", args, access_token: reviewer_token)
    aggregate_failures do
      expect_reference_refusal(response)
      expect(content_state).to eq(before_state),
      "APPROVAL ATOMICITY: denied mandatory parent persisted"
    end
  end

  it "[cr-u4] keeps genuine short-url attachments and genuine user and group mentions" do
    activate!
    upload = review3_upload
    group =
      Fabricate(
        :group,
        name: "reviewthreeallowed",
        mentionable_level: Group::ALIAS_LEVELS[:everyone],
      )
    raw =
      "Read [garden notes|attachment](#{upload.short_url}) with @#{recipient.username} and @#{group.name}."
    data = expect_success(rpc("discourse_create_post", { topic_id: post.topic_id, raw: }))
    cooked = Nokogiri::HTML5.fragment(Post.find(data.fetch("id")).cooked)
    expect(cooked.at_css("a.attachment")["href"]).to eq(upload.short_path)
    expect(cooked.at_css("a.mention")["href"]).to eq("/u/#{recipient.username.downcase}")
    expect(cooked.at_css("a.mention-group")["href"]).to eq("/groups/#{group.name}")
  end

  it "[cr-u4] keeps synonym-only allowed topics under the tag limit" do
    SiteSetting.max_tags_per_topic = 2
    target = Fabricate(:tag, id: 111_730_030, name: "reviewthreeallowedtarget")
    aliases =
      [31, 32].map do |offset|
        Fabricate(
          :tag,
          id: 111_730_000 + offset,
          name: "reviewthreeallowed#{offset}",
          target_tag: target,
        )
      end
    activate!
    data = expect_success(rpc("discourse_create_topic", topic_arguments(tags: aliases.map(&:name))))
    expect(Topic.find(data.fetch("topic_id")).tags).to contain_exactly(target)
  end

  it "[cr-u4] keeps staff approval of an allowed queued topic using staff tag permissions" do
    SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
    tag = Fabricate(:tag, id: 111_730_040, name: "reviewthreeallowedqueued")
    reviewable = review3_queue([tag.name], author: recipient)
    expect(recipient.guardian.can_tag_topics?).to eq(false)
    activate!
    expect_success(
      rpc(
        "discourse_perform_reviewable_action",
        { reviewable_id: reviewable.id, action_id: "approve_post", confirm: true },
      ),
    )
    expect(reviewable.reload.status).to eq("approved")
    expect(reviewable.target.topic.tags).to contain_exactly(tag)
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
