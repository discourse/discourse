# frozen_string_literal: true

require_relative "write_support"

# Each variant is calibrated against its own unrestricted baseline.
# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with MCP content write rules"

  %i[create update draft].each do |operation|
    it "gives unknown and denied #{operation} tags the same refusal without implicitly creating tags" do
      name, base =
        case operation
        when :create
          ["discourse_create_topic", topic_arguments]
        when :update
          [
            "discourse_update_topic",
            { topic_id: post.topic_id, title: "Revised seasonal garden discussion" },
          ]
        else
          [
            "discourse_save_draft",
            {
              draft_key: Draft::NEW_TOPIC,
              reply: McpContentWriteHelpers::PROSE,
              title: "Seasonal discussion with tags",
            },
          ]
        end
      unknown = "u4-never-created"
      [unknown, denied_tag.name].each do |tag_name|
        isolated do
          data = expect_success(rpc(name, base.merge(tags: [tag_name])))
          if operation != :draft
            topic_id = data["topic_id"]
            expect(Topic.find(topic_id).tags.map(&:name)).to include(tag_name)
          end
        end
      end
      activate!
      responses =
        [unknown, denied_tag.name].map do |tag_name|
          response = nil
          isolated do
            state = content_state
            response = rpc(name, base.merge(tags: [tag_name]))
            aggregate_failures do
              expect_refusal(response)
              expect(Tag.exists?(name: unknown)).to eq(false),
              "IMPLICIT TAG: unknown tag was created"
              expect(content_state).to eq(state), "TAG ATOMICITY: refused tags changed content"
            end
          end
          response
        end
      expect(responses.uniq.size).to eq(1),
      "TAG PARITY: unknown and denied tags must have identical answers"
    end
  end

  %i[synonym parent].each do |expansion|
    %i[create update move].each do |operation|
      it "refuses #{operation} whose effective #{expansion} tag is denied like a missing category" do
        child = Fabricate(:tag, name: "u4-child")
        if expansion == :synonym
          child.update!(target_tag: denied_tag)
        else
          tag_group = Fabricate(:tag_group, parent_tag_id: denied_tag.id)
          tag_group.tags = [child]
        end
        destination = Fabricate(:category)
        name, args =
          if operation == :create
            ["discourse_create_topic", topic_arguments(tags: [child.name])]
          else
            attrs = {
              topic_id: post.topic_id,
              title: "Revised seasonal garden discussion",
              tags: [child.name],
            }
            attrs[:category_id] = destination.id if operation == :move
            ["discourse_update_topic", attrs]
          end
        isolated do
          data = expect_success(rpc(name, args))
          expect(Topic.find(data.fetch("topic_id")).tags).to include(denied_tag)
        end
        activate!
        missing_response = nil
        isolated do
          missing_response =
            rpc(name, args.except(:tags).merge(category_id: McpContentWriteHelpers::MISSING_ID))
          expect_refusal(missing_response)
        end
        before_state = content_state
        response = rpc(name, args)
        aggregate_failures do
          expect_refusal(response)
          expect(response).to eq(missing_response),
          "PROSPECTIVE TAGS: effective denied tags must answer like a missing category"
          expect(content_state).to eq(before_state),
          "PROSPECTIVE ATOMICITY: restricted result persisted"
        end
      end
    end
  end

  %i[create update draft].each do |operation|
    it "refuses unknown #{operation} tags under a PM-only rule without creating them" do
      name, args =
        case operation
        when :create
          ["discourse_create_topic", topic_arguments]
        when :update
          [
            "discourse_update_topic",
            { topic_id: post.topic_id, title: "Seasonal garden observations" },
          ]
        else
          [
            "discourse_save_draft",
            { draft_key: Draft::NEW_TOPIC, reply: McpContentWriteHelpers::PROSE },
          ]
        end
      unknown = "u4-new-pm-rule-tag"
      args[:tags] = [unknown]
      isolated { expect_success(rpc(name, args)) }
      activate!(:pm)
      state = content_state
      response = rpc(name, args)
      aggregate_failures do
        expect_refusal(response)
        expect(Tag.exists?(name: unknown)).to eq(false),
        "IMPLICIT TAG: PM-only rule created an unknown tag"
        expect(content_state).to eq(state)
      end
    end
  end

  %i[synonym parent].each do |expansion|
    it "expands watched-word #{expansion} tags before checking prospective access" do
      child = Fabricate(:tag, name: "u4-watched-child")
      if expansion == :synonym
        child.update!(target_tag: denied_tag)
      else
        Fabricate(:tag_group, parent_tag_id: denied_tag.id, tags: [child])
      end
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:tag],
        word: "u4gardenspecial",
        replacement: child.name,
      )
      args = topic_arguments(raw: "Seasonal u4gardenspecial observations about gardens.")
      isolated do
        data = expect_success(rpc("discourse_create_topic", args))
        expect(Topic.find(data.fetch("topic_id")).tags).to include(denied_tag)
      end
      activate!
      missing =
        rpc("discourse_create_topic", args.merge(category_id: McpContentWriteHelpers::MISSING_ID))
      state = content_state
      response = rpc("discourse_create_topic", args)
      aggregate_failures do
        expect_refusal(response)
        expect(response).to eq(missing),
        "WATCHED TAGS: expanded denial must answer like a missing category"
        expect(content_state).to eq(state)
      end
    end
  end

  %i[title raw].each do |field|
    it "refuses create whose watched-word #{field} adds a denied tag" do
      word = "u4gardenspecial"
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:tag],
        word: word,
        replacement: denied_tag.name,
      )
      args =
        topic_arguments(**{ field => "Seasonal observations about #{word} and growing flowers." })
      isolated do
        data = expect_success(rpc("discourse_create_topic", args))
        expect(Topic.find(data.fetch("topic_id")).tags).to include(denied_tag)
      end
      activate!
      missing =
        rpc("discourse_create_topic", args.merge(category_id: McpContentWriteHelpers::MISSING_ID))
      before_state = content_state
      response = rpc("discourse_create_topic", args)
      aggregate_failures do
        expect_refusal(response)
        expect(response).to eq(missing),
        "WATCHED TAGS: effective denied tag must answer like a missing category"
        expect(content_state).to eq(before_state)
      end
    end
  end

  it "refuses a watched-word tag name that does not yet exist without creating it" do
    name = "u4-unborn-tag"
    stale_tag = Fabricate(:tag, name: name)
    Fabricate(
      :watched_word,
      action: WatchedWord.actions[:tag],
      word: "u4gardenspecial",
      replacement: name,
    )
    stale_tag.destroy!
    args = topic_arguments(raw: "Observations about u4gardenspecial and growing flowers.")
    isolated do
      data = expect_success(rpc("discourse_create_topic", args))
      expect(Topic.find(data.fetch("topic_id")).tags.map(&:name)).to include(name)
    end
    activate!(:pm)
    response = rpc("discourse_create_topic", args)
    aggregate_failures do
      expect_refusal(response)
      expect(Tag.exists?(name: name)).to eq(false), "WATCHED TAG: unknown watched tag was created"
    end
  end

  it "evaluates watched words only for creates, preserving allowed title updates" do
    Fabricate(
      :watched_word,
      action: WatchedWord.actions[:tag],
      word: "u4gardenspecial",
      replacement: denied_tag.name,
    )
    args = { topic_id: post.topic_id, title: "Seasonal u4gardenspecial observations about gardens" }
    isolated do
      expect_success(rpc("discourse_update_topic", args))
      expect(post.topic.reload.tags).to be_empty
    end
    activate!
    expect_success(rpc("discourse_update_topic", args))
    expect(post.topic.reload.tags).to be_empty
  end

  it "rolls back an UpdateTopic whose stored result ends restricted, including title and revision changes" do
    args = {
      topic_id: post.topic_id,
      title: "Revised seasonal garden discussion",
      tags: [denied_tag.name],
    }
    isolated do
      expect_success(rpc("discourse_update_topic", args))
      expect(post.topic.reload.tags).to include(denied_tag)
    end
    activate!
    before_state = content_state
    revisions = PostRevision.where(post_id: post.id).pluck(:number, :modifications)
    expect_refusal(rpc("discourse_update_topic", args))
    expect(content_state).to eq(before_state)
    expect(PostRevision.where(post_id: post.id).pluck(:number, :modifications)).to eq(revisions)
  end

  it "preserves normalization and allowed synonyms without a blanket ban on tag writes" do
    allowed_tag = Fabricate(:tag, name: "u4-flowers")
    synonym = Fabricate(:tag, name: "u4-flower-alias", target_tag: allowed_tag)
    args = topic_arguments(tags: [synonym.name.upcase])
    isolated do
      data = expect_success(rpc("discourse_create_topic", args))
      expect(Topic.find(data.fetch("topic_id")).tags).to contain_exactly(allowed_tag)
    end
    activate!
    data = expect_success(rpc("discourse_create_topic", args))
    expect(Topic.find(data.fetch("topic_id")).tags).to contain_exactly(allowed_tag)
  end

  describe "with watched-word tags and queued topics" do
    def queued_topic(payload = {}, **attributes)
      Fabricate(
        :reviewable_queued_post_topic,
        category: allowed_category,
        target_created_by: recipient,
        payload: {
          raw: McpContentWriteHelpers::PROSE,
          title: "Queued observations about seasonal gardens",
          tags: [],
          archetype: "regular",
        }.merge(payload),
        **attributes,
      )
    end

    def approve_arguments(reviewable, action = "approve_post")
      { reviewable_id: reviewable.id, action_id: action, confirm: true }
    end

    it "refuses a new PM whose watched words add a denied tag" do
      SiteSetting.pm_tags_allowed_for_groups = Group::AUTO_GROUPS[:everyone].to_s
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:tag],
        word: "u4reviewgarden",
        replacement: denied_tag.name,
      )
      args = {
        title: "An exchange about seasonal gardens",
        raw: "These are u4reviewgarden observations about changing seasons.",
        usernames: [recipient.username],
      }
      isolated do
        data = expect_success(rpc("discourse_create_private_message", args))
        topic = Topic.find(data.fetch("topic_id"))
        expect(topic.private_message?).to eq(true)
        expect(topic.tags).to include(denied_tag)
      end
      activate!
      assert_reference_write("discourse_create_private_message", args)
    end

    %i[payload_category hash_tags parent watched_word].each do |restriction|
      it "refuses queued topic approval made restricted by #{restriction}" do
        payload = {}
        attributes = {}
        case restriction
        when :payload_category
          payload[:category] = restricted_category.id
          attributes[:category] = nil
        when :hash_tags
          payload[:tags] = [{ "name" => denied_tag.name }]
        when :parent
          child = Fabricate(:tag, name: "u4-review-child")
          Fabricate(:tag_group, parent_tag_id: denied_tag.id, tags: [child])
          payload[:tags] = [child.name]
        else
          Fabricate(
            :watched_word,
            action: WatchedWord.actions[:tag],
            word: "u4reviewgarden",
            replacement: denied_tag.name,
          )
          payload[:raw] = "These are u4reviewgarden observations about changing seasons."
        end
        reviewable = queued_topic(payload, **attributes)
        args = approve_arguments(reviewable)
        isolated do
          expect_success(rpc("discourse_perform_reviewable_action", args))
          expect(reviewable.reload.status).to eq("approved")
          topic = reviewable.target.topic
          if restriction == :payload_category
            expect(topic.category_id).to eq(restricted_category.id)
          else
            expect(topic.tags).to include(denied_tag)
          end
        end
        activate!
        assert_reference_write("discourse_perform_reviewable_action", args)
      end
    end

    it "permits a PM and queued new topic whose effective tags stay allowed" do
      allowed_tag = Fabricate(:tag, name: "u4-review-flowers")
      child = Fabricate(:tag, name: "u4-review-flower-child")
      Fabricate(:tag_group, parent_tag_id: allowed_tag.id, tags: [child])
      Fabricate(
        :watched_word,
        action: WatchedWord.actions[:tag],
        word: "u4reviewgarden",
        replacement: child.name,
      )
      SiteSetting.pm_tags_allowed_for_groups = Group::AUTO_GROUPS[:everyone].to_s
      raw = "These are u4reviewgarden observations about changing seasons."
      reviewable = queued_topic({ raw: raw })
      activate!
      data =
        expect_success(
          rpc(
            "discourse_create_private_message",
            {
              title: "An exchange about seasonal gardens",
              raw: raw,
              usernames: [recipient.username],
            },
          ),
        )
      message = Topic.find(data.fetch("topic_id"))
      expect(message.private_message?).to eq(true)
      expect(message.tags).to contain_exactly(child, allowed_tag)
      expect_success(rpc("discourse_perform_reviewable_action", approve_arguments(reviewable)))
      expect(reviewable.reload.status).to eq("approved")
      expect(reviewable.target.topic.category_id).to eq(allowed_category.id)
      expect(reviewable.target.topic.tags).to contain_exactly(child, allowed_tag)
    end
  end

  describe "with tag names normalized on save" do
    def queued_topic(tags)
      Fabricate(
        :reviewable_queued_post_topic,
        category: allowed_category,
        target_created_by: admin,
        payload: {
          raw: McpContentWriteHelpers::PROSE,
          title: "Queued observations about seasonal gardens",
          tags: tags,
          archetype: "regular",
        },
      )
    end

    def approve(reviewable)
      rpc(
        "discourse_perform_reviewable_action",
        { reviewable_id: reviewable.id, action_id: "approve_post", confirm: true },
      )
    end

    %i[case whitespace truncation].each do |shape|
      it "judges #{shape} tag names by the tags saving stores and answers like a missing category" do
        SiteSetting.max_tag_length = 60
        long = Fabricate(:tag, name: "reviewtwogardenextended")
        limit = shape == :truncation ? 8 : 15
        denied_tag.update!(name: long.name.first(limit))
        SiteSetting.max_tag_length = limit
        name = shape == :whitespace ? " #{long.name} " : long.name.upcase
        args = topic_arguments(tags: [name])
        isolated do
          data = expect_success(rpc("discourse_create_topic", args))
          stored = Post.find(data.fetch("id")).topic.tags
          expected = shape == :whitespace ? [denied_tag] : [long, denied_tag]
          expect(stored).to match_array(expected)
        end
        activate!
        missing_response = nil
        isolated do
          missing_response =
            rpc(
              "discourse_create_topic",
              args.except(:tags).merge(category_id: McpContentWriteHelpers::MISSING_ID),
            )
          expect_refusal(missing_response)
        end
        before_state = content_state
        response = rpc("discourse_create_topic", args)
        aggregate_failures do
          expect_refusal(response)
          expect(response).to eq(missing_response),
          "PROSPECTIVE TAGS: effective denied tags must answer like a missing category"
          expect(content_state).to eq(before_state),
          "WRITE ATOMICITY: refused reference persisted content"
        end
      end
    end

    %i[without_id with_id].each do |shape|
      it "judges queued hash tags #{shape} by saving and keeps allowed hash tags" do
        SiteSetting.max_tag_length = 60
        long = Fabricate(:tag, name: "reviewtwoqueuedextended")
        allowed = Fabricate(:tag, name: "review-two-allowed")
        denied_tag.update!(name: long.name.first(12))
        SiteSetting.max_tag_length = 12
        entry = { "name" => long.name.upcase }
        entry["id"] = long.id if shape == :with_id
        reviewable = queued_topic([entry])
        isolated do
          expect_success(approve(reviewable))
          expect(reviewable.reload.target.topic.tags).to contain_exactly(long, denied_tag)
        end
        reviewable.reload
        activate!
        allowed_entry = { "name" => allowed.name }
        allowed_entry["id"] = allowed.id if shape == :with_id
        control = queued_topic([allowed_entry])
        expect_success(approve(control))
        expect(control.reload.status).to eq("approved")
        expect(control.target.topic.tags).to contain_exactly(allowed)
        assert_reference_write(
          "discourse_perform_reviewable_action",
          { reviewable_id: reviewable.id, action_id: "approve_post", confirm: true },
        )
      end
    end
  end

  describe "with synonyms, parent tags and staff approval" do
    def queued_topic(tags, author: admin)
      Fabricate(
        :reviewable_queued_post_topic,
        category: allowed_category,
        target_created_by: author,
        payload: {
          raw: McpContentWriteHelpers::PROSE,
          title: "Queued seasonal garden observations",
          tags: tags,
          archetype: "regular",
        },
      )
    end

    it "judges watched-word tags after synonymous input tags collapse under the tag limit" do
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
        topic_arguments(
          tags: aliases.map(&:name),
          raw: "Seasonal reviewthreegardenspecial gardens.",
        )
      isolated do
        data = expect_success(rpc("discourse_create_topic", args))
        expect(Topic.find(data.fetch("topic_id")).tags).to contain_exactly(target, denied_tag)
      end
      activate!
      missing =
        rpc("discourse_create_topic", args.merge(category_id: McpContentWriteHelpers::MISSING_ID))
      before_state = content_state
      response = rpc("discourse_create_topic", args)
      aggregate_failures do
        expect_refusal(response)
        expect(response).to eq(missing)
        expect(content_state).to eq(before_state),
        "PROSPECTIVE ATOMICITY: denied watched tag persisted"
      end
    end

    it "judges category-reviewer approval by the queued author's child and mandatory parent tags" do
      SiteSetting.enable_category_group_moderation = true
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
      membership = Fabricate(:group_user)
      reviewer = membership.user
      Fabricate(:category_moderation_group, category: allowed_category, group: membership.group)
      reviewer_token = issue_token(reviewer)
      child = Fabricate(:tag, id: 111_730_020, name: "reviewthreechild")
      Fabricate(:tag_group, parent_tag: denied_tag, tags: [child])
      reviewable = queued_topic([child.name])
      args = { reviewable_id: reviewable.id, action_id: "approve_post", confirm: true }
      expect(reviewer.staff?).to eq(false)
      expect(reviewer.guardian.can_see_review_queue?).to eq(true)
      expect(reviewer.guardian.can_tag_topics?).to eq(false)
      expect(admin.guardian.can_tag_topics?).to eq(true)
      isolated do
        expect_success(
          rpc("discourse_perform_reviewable_action", args, access_token: reviewer_token),
        )
        expect(reviewable.reload.status).to eq("approved")
        expect(reviewable.target.topic.tags).to contain_exactly(child, denied_tag)
      end
      reviewable.reload
      activate!
      allowed_parent = Fabricate(:tag, id: 111_730_021, name: "reviewthreeallowedparent")
      allowed_child = Fabricate(:tag, id: 111_730_022, name: "reviewthreeallowedchild")
      Fabricate(:tag_group, parent_tag: allowed_parent, tags: [allowed_child])
      control = queued_topic([allowed_child.name])
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

    it "keeps synonym-only allowed topics under the tag limit" do
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
      data =
        expect_success(rpc("discourse_create_topic", topic_arguments(tags: aliases.map(&:name))))
      expect(Topic.find(data.fetch("topic_id")).tags).to contain_exactly(target)
    end

    it "keeps staff approval of an allowed queued topic using staff tag permissions" do
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
      tag = Fabricate(:tag, id: 111_730_040, name: "reviewthreeallowedqueued")
      reviewable = queued_topic([tag.name], author: recipient)
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

  describe "with category tag filtering and non-staff approval" do
    before { SiteSetting.unique_posts_mins = 0 }

    def persisted_state
      {
        posts: Post.with_deleted.order(:id).pluck(:id, :topic_id, :raw, :cooked, :deleted_at),
        topics: Topic.with_deleted.order(:id).pluck(:id, :title, :category_id, :deleted_at),
        topic_tags: TopicTag.order(:topic_id, :tag_id).pluck(:topic_id, :tag_id),
        tags: Tag.order(:id).pluck(:id, :name),
        reviewables: Reviewable.order(:id).pluck(:id, :status, :topic_id, :target_id, :payload),
      }
    end

    def queued_topic(tags:, raw: McpContentWriteHelpers::PROSE, author: admin)
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

    def approve(reviewable, access_token: token)
      rpc(
        "discourse_perform_reviewable_action",
        { reviewable_id: reviewable.id, action_id: "approve_post", confirm: true },
        access_token:,
      )
    end

    def category_tags
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

    def category_rule(denied)
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

    def category_reviewer_token
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
      it "refuses #{writer} after category filtering frees a denied watched-tag slot without persisting content" do
        kept, filtered, _watched, denied = category_tags
        raw = "Seasonal reviewfourdeniedword garden observations."
        args = topic_arguments(tags: [kept.name, filtered.name], raw:)
        reviewable = queued_topic(tags: args[:tags], raw:) if writer == :queued_approval
        write = -> do
          if reviewable
            approve(reviewable)
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
        category_rule(denied)
        expected =
          if reviewable
            reference_error
          else
            rpc(
              "discourse_create_topic",
              args.except(:tags).merge(category_id: McpContentWriteHelpers::MISSING_ID),
            )
          end
        expect_refusal(expected)
        before_state = persisted_state
        response = write.call
        aggregate_failures do
          expect_refusal(response)
          expect(response).to eq(expected), "CATEGORY FILTER: refusal envelope changed"
          expect(persisted_state).to eq(before_state),
          "CATEGORY FILTER ATOMICITY: topic, post or tags persisted"
        end
      end

      it "persists allowed #{writer} after category filtering frees an allowed watched-tag slot" do
        kept, filtered, watched, denied = category_tags
        raw = "Seasonal reviewfourallowedword garden observations."
        category_rule(denied)
        if writer == :queued_approval
          reviewable = queued_topic(tags: [kept.name, filtered.name], raw:)
          expect_success(approve(reviewable))
          expect(reviewable.reload.status).to eq("approved")
          topic = reviewable.target.topic
        else
          data =
            expect_success(
              rpc(
                "discourse_create_topic",
                topic_arguments(tags: [kept.name, filtered.name], raw:),
              ),
            )
          topic = Topic.find(data.fetch("topic_id"))
        end
        expect(topic.tags).to contain_exactly(kept, watched)
        expect(topic.posts.sole.raw).to eq(raw)
      end
    end

    %i[string object].each do |shape|
      it "refuses non-staff approval of a non-tagging author's #{shape} payload tags without persisting content" do
        reviewer_token = category_reviewer_token
        entry = shape == :object ? { "name" => denied_tag.name } : " #{denied_tag.name} "
        reviewable = queued_topic(tags: [entry], author: recipient)
        expect(reviewer_token.user.guardian.can_see_review_queue?).to eq(true)
        isolated do
          expect_success(approve(reviewable, access_token: reviewer_token))
          expect(reviewable.reload.status).to eq("approved")
          expect(reviewable.target.topic.tags).to contain_exactly(denied_tag)
        end
        reviewable.reload
        activate!
        expected = reference_error
        before_state = persisted_state
        response = approve(reviewable, access_token: reviewer_token)
        aggregate_failures do
          expect_refusal(response)
          expect(response).to eq(expected), "QUEUED FALLBACK: refusal envelope changed"
          expect(persisted_state).to eq(before_state),
          "QUEUED FALLBACK ATOMICITY: topic, post, tags or approval persisted"
        end
      end

      it "persists non-staff approval of a non-tagging author's allowed #{shape} payload tags" do
        reviewer_token = category_reviewer_token
        allowed = Fabricate(:tag, id: 112_840_020, name: "reviewfourfallback")
        entry = shape == :object ? { "name" => allowed.name } : " #{allowed.name} "
        reviewable = queued_topic(tags: [entry], author: recipient)
        expect(reviewer_token.user.guardian.can_see_review_queue?).to eq(true)
        activate!
        expect_success(approve(reviewable, access_token: reviewer_token))
        expect(reviewable.reload.status).to eq("approved")
        expect(reviewable.target.topic.tags).to contain_exactly(allowed)
        expect(reviewable.target.reload.raw).to eq(reviewable.payload.fetch("raw"))
      end
    end

    it "refuses a denied watched-tag private message atomically and persists an allowed watched-tag private message" do
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
      before_state = persisted_state
      response = rpc("discourse_create_private_message", args)
      aggregate_failures do
        expect_refusal(response)
        expect(response).to eq(expected)
        expect(persisted_state).to eq(before_state)
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
