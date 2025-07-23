# frozen_string_literal: true

require "rails_helper"
require "post_revisor"

describe PostRevisor do
  fab!(:category) { Fabricate(:category_with_definition) }
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

  describe "Allowing solved via tags" do
    before do
      SiteSetting.solved_enabled = true
      SiteSetting.tagging_enabled = true
    end

    fab!(:tag1) { Fabricate(:tag) }
    fab!(:tag2) { Fabricate(:tag) }

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
