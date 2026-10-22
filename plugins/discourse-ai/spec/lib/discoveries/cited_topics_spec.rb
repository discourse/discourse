# frozen_string_literal: true

RSpec.describe DiscourseAi::Discoveries::CitedTopics do
  subject(:cited_topics) do
    described_class.new(topic: conversation, guardian: user.guardian).as_json
  end

  fab!(:user)
  fab!(:bot, :user)
  fab!(:conversation) { Fabricate(:private_message_topic, user:, recipient: bot) }
  fab!(:source, :topic)
  fab!(:first_cited, :topic)
  fab!(:second_cited, :topic)
  fab!(:hidden) do
    Fabricate(:topic, category: Fabricate(:private_category, group: Fabricate(:group)))
  end

  before do
    enable_current_plugin
    conversation.custom_fields[
      DiscourseAi::Discoveries::ContinueConversation::TOPIC_SOURCES_FIELD
    ] = [{ "topic_id" => source.id, "title" => source.title, "url" => source.url }]
    conversation.save_custom_fields

    Fabricate(:post, topic: conversation, user:, raw: "How do I reset my password?")
    Fabricate(:post, topic: conversation, user: bot, raw: <<~MD)
      See [the guide](#{first_cited.url}), [a hidden one](#{hidden.url}) and
      [elsewhere](https://example.com/t/some-topic/#{second_cited.id}).
    MD
    Fabricate(:post, topic: conversation, user:, raw: "And two factor?")
    Fabricate(:post, topic: conversation, user: bot, raw: "Try [this](#{second_cited.url}).")
  end

  it "lists the answer's sources, then what each reply links to, by the reply that cited it" do
    expect(cited_topics[:replies]).to eq(2)
    expect(cited_topics[:topics].map { |topic| topic.slice(:topic_id, :turn) }).to eq(
      [
        { topic_id: source.id, turn: 0 },
        { topic_id: first_cited.id, turn: 0 },
        { topic_id: second_cited.id, turn: 1 },
      ],
    )
  end

  it "gives what a topic list row shows of each topic" do
    expect(cited_topics[:topics].first).to include(
      title: source.title,
      url: source.relative_url,
      category_id: source.category_id,
      reply_count: source.posts_count - 1,
    )
  end
end
