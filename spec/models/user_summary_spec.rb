require 'rails_helper'

describe UserSummary do

  it "produces secure summaries" do
    topic = create_post.topic
    user = topic.user
    _reply = create_post(user: topic.user, topic: topic)

    summary = UserSummary.new(user, Guardian.new)

    expect(summary.topics.length).to eq(1)
    expect(summary.replies.length).to eq(1)

    topic.update_columns(deleted_at: Time.now)

    expect(summary.topics.length).to eq(0)
    expect(summary.replies.length).to eq(0)

    topic.update_columns(deleted_at: nil, visible: false)

    expect(summary.topics.length).to eq(0)
    expect(summary.replies.length).to eq(0)

    category = Fabricate(:category)
    topic.update_columns(category_id: category.id, deleted_at: nil, visible: true)

    category.set_permissions(staff: :full)
    category.save

    expect(summary.topics.length).to eq(0)
    expect(summary.replies.length).to eq(0)

  end

end
