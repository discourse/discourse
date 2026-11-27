# frozen_string_literal: true

RSpec.describe "import:ensure_consistency" do
  fab!(:user)
  fab!(:second_poster, :user)
  fab!(:third_poster, :user)

  it "recomputes participant_count from the distinct post authors" do
    topic = Fabricate(:post, user:).topic
    Fabricate(:post, topic:, user: second_poster)
    Fabricate(:post, topic:, user: third_poster)

    # An import copies posts without the column, leaving it at its default.
    topic.update_columns(participant_count: 1)

    capture_stdout { invoke_rake_task("import:ensure_consistency") }

    expect(topic.reload.participant_count).to eq(3)
  end

  it "ignores hidden, deleted and small action posts when counting authors" do
    topic = Fabricate(:post, user:).topic
    Fabricate(:post, topic:, user: second_poster)
    Fabricate(:post, topic:, user: third_poster).update_columns(hidden: true)
    Fabricate(:post, topic:, user: third_poster).update_columns(deleted_at: Time.now)
    Fabricate(:post, topic:, user: third_poster, post_type: Post.types[:small_action])

    topic.update_columns(participant_count: 1)

    capture_stdout { invoke_rake_task("import:ensure_consistency") }

    expect(topic.reload.participant_count).to eq(2)
  end
end
