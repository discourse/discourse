# frozen_string_literal: true

require_relative "support"

# Each matrix cell needs an independent baseline receipt.
# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server, "#call" do
  include_context "with unit four MCP writes"

  %i[create update draft].each do |operation|
    it "[cr-u4] gives unknown and denied #{operation} tags the same refusal without implicitly creating tags" do
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
              reply: McpContentRestrictionsUnit4::PROSE,
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
      "TAG ORACLE: unknown and denied tags must have identical answers"
    end
  end

  %i[synonym parent].each do |expansion|
    %i[create update move].each do |operation|
      it "[cr-u4] refuses #{operation} whose effective #{expansion} tag is denied like a missing category" do
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
            rpc(
              name,
              args.except(:tags).merge(category_id: McpContentRestrictionsUnit4::MISSING_ID),
            )
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
    it "[cr-u4] refuses unknown #{operation} tags under a PM-only rule without creating them" do
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
            { draft_key: Draft::NEW_TOPIC, reply: McpContentRestrictionsUnit4::PROSE },
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
    it "[cr-u4] expands watched-word #{expansion} tags before checking prospective access" do
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
        rpc(
          "discourse_create_topic",
          args.merge(category_id: McpContentRestrictionsUnit4::MISSING_ID),
        )
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
    it "[cr-u4] refuses create whose watched-word #{field} adds a denied tag" do
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
        rpc(
          "discourse_create_topic",
          args.merge(category_id: McpContentRestrictionsUnit4::MISSING_ID),
        )
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

  it "[cr-u4] refuses a watched-word tag name that does not yet exist without creating it" do
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

  it "[cr-u4] evaluates watched words only for creates, preserving allowed title updates" do
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

  it "[cr-u4] rolls back an UpdateTopic whose stored result ends restricted, including title and revision changes" do
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

  it "[cr-u4] preserves normalization and allowed synonyms without a blanket ban on tag writes" do
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
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
