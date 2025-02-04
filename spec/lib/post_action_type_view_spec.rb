# frozen_string_literal: true

RSpec.describe PostActionTypeView do
  let(:post_action_type_view) { PostActionTypeView.new }

  it "returns correct types" do
    expect(post_action_type_view.flag_types).to eq(
      {
        illegal: 10,
        inappropriate: 4,
        notify_moderators: 7,
        notify_user: 6,
        off_topic: 3,
        spam: 8,
      },
    )
    expect(post_action_type_view.public_types).to eq({ like: 2 })

    expect(post_action_type_view.notify_flag_types).to eq(
      { illegal: 10, inappropriate: 4, notify_moderators: 7, off_topic: 3, spam: 8 },
    )

    expect(post_action_type_view.topic_flag_types).to eq(
      { illegal: 10, inappropriate: 4, notify_moderators: 7, spam: 8 },
    )

    expect(post_action_type_view.additional_message_types).to eq(
      { illegal: 10, notify_moderators: 7, notify_user: 6 },
    )
    expect(post_action_type_view.score_types).to eq({ needs_approval: 9 })

    flag = Fabricate(:flag, name: "flag", enabled: false)
    expect(PostActionTypeView.new.disabled_flag_types).to eq({ custom_flag: flag.id })
    flag.destroy!
  end

  it "defines names of flags" do
    expect(post_action_type_view.names).to eq(
      {
        6 => "notify_user",
        3 => "off_topic",
        4 => "inappropriate",
        8 => "spam",
        10 => "illegal",
        7 => "notify_moderators",
        9 => "needs_approval",
        2 => "like",
      },
    )
  end

  it "defines descriptions of flags" do
    flag = Fabricate(:flag, enabled: false, description: "custom flag description")
    expect(post_action_type_view.descriptions[flag.id]).to eq("custom flag description")
    flag.destroy!
  end

  it "defines where flags can be applies to" do
    expect(post_action_type_view.applies_to).to eq(
      {
        6 => %w[Post Chat::Message],
        3 => %w[Post Chat::Message],
        4 => %w[Post Topic Chat::Message],
        8 => %w[Post Topic Chat::Message],
        10 => %w[Post Topic Chat::Message],
        7 => %w[Post Topic Chat::Message],
        9 => [],
        2 => ["Post"],
      },
    )
  end

  it "defines is post action type is a flag" do
    expect(post_action_type_view.is_flag?(:like)).to be false
    expect(post_action_type_view.is_flag?(:off_topic)).to be true
  end
end
