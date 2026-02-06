# frozen_string_literal: true

require "post_revisor"

describe PostRevisor do
  fab!(:category, :category_with_definition)
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }

  fab!(:category_solved) do
    category = Fabricate(:category_with_definition)
    category.upsert_custom_fields("enable_accepted_answers" => "true")
    category
  end

  it "refreshes post stream when topic category changes to a solved category" do
    topic = Fabricate(:topic, category: Fabricate(:category_with_definition))
    post = Fabricate(:post, topic: topic)

    messages =
      MessageBus.track_publish("/topic/#{topic.id}") do
        described_class.new(post).revise!(admin, { category_id: category.id })
      end

    expect(messages.first.data[:refresh_stream]).to eq(nil)

    messages =
      MessageBus.track_publish("/topic/#{topic.id}") do
        described_class.new(post).revise!(admin, { category_id: category_solved.id })
      end

    expect(messages.first.data[:refresh_stream]).to eq(true)
  end

  describe "Unaccepting answer on category change" do
    fab!(:topic) { Fabricate(:topic, category: category_solved) }
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:reply) { Fabricate(:post, topic: topic, post_number: 2) }

    before do
      SiteSetting.solved_enabled = true
      DiscourseSolved.accept_answer!(reply, admin)
      topic.reload
    end

    it "unaccepts the answer when category changes from solved to unsolved" do
      described_class.new(post).revise!(admin, { category_id: category.id })
      topic.reload
      expect(topic.solved).to be_nil
    end

    it "keeps the answer when category changes to another solved category" do
      another_solved =
        Fabricate(:category_with_definition).tap do |c|
          c.upsert_custom_fields("enable_accepted_answers" => "true")
        end
      DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache

      described_class.new(post).revise!(admin, { category_id: another_solved.id })
      topic.reload
      expect(topic.solved).to be_present
      expect(topic.solved.answer_post_id).to eq(reply.id)
    end

    it "keeps the answer when allow_solved_on_all_topics is true" do
      SiteSetting.allow_solved_on_all_topics = true

      described_class.new(post).revise!(admin, { category_id: category.id })
      topic.reload
      expect(topic.solved).to be_present
      expect(topic.solved.answer_post_id).to eq(reply.id)
    end
  end

  describe "Unaccepting answer on tag change" do
    before do
      SiteSetting.solved_enabled = true
      SiteSetting.tagging_enabled = true
    end

    fab!(:solved_tag, :tag)
    fab!(:topic) { Fabricate(:topic, tags: [solved_tag]) }
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:reply) { Fabricate(:post, topic: topic, post_number: 2) }

    it "unaccepts the answer when the solved tag is removed" do
      SiteSetting.enable_solved_tags = solved_tag.name
      DiscourseSolved.accept_answer!(reply, admin)
      topic.reload

      described_class.new(post).revise!(admin, tags: [])
      topic.reload
      expect(topic.solved).to be_nil
    end
  end

  describe "Allowing solved via tags" do
    before do
      SiteSetting.solved_enabled = true
      SiteSetting.tagging_enabled = true
    end

    fab!(:tag1, :tag)
    fab!(:tag2, :tag)

    fab!(:topic)
    let(:post) { Fabricate(:post, topic: topic) }

    it "sets the refresh option after adding an allowed tag" do
      SiteSetting.enable_solved_tags = tag1.name

      messages =
        MessageBus.track_publish("/topic/#{topic.id}") do
          described_class.new(post).revise!(admin, tags: [tag1.name])
        end

      expect(messages.first.data[:refresh_stream]).to eq(true)
    end

    it "sets the refresh option if the added tag matches any of the allowed tags" do
      SiteSetting.enable_solved_tags = [tag1, tag2].map(&:name).join("|")

      messages =
        MessageBus.track_publish("/topic/#{topic.id}") do
          described_class.new(post).revise!(admin, tags: [tag2.name])
        end

      expect(messages.first.data[:refresh_stream]).to eq(true)
    end
  end
end
