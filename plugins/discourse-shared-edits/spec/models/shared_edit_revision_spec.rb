# frozen_string_literal: true

RSpec.describe SharedEditRevision do
  def fake_edit(post, user_id, content, version:)
    yjs_update = { content: content, timestamp: Time.current.to_i, version: version + 1 }.to_json
    SharedEditRevision.revise!(
      post_id: post.id,
      user_id: user_id,
      client_id: user_id.to_s,
      revision: yjs_update,
      version: version,
    )
  end

  it "can resolve edits and notify" do
    raw = "Hello world"

    user1 = Fabricate(:user)
    user2 = Fabricate(:user)

    post = Fabricate(:post, raw: raw)
    SharedEditRevision.init!(post)

    version, revision = nil

    # User 1 makes an edit
    messages =
      MessageBus.track_publish("/shared_edits/#{post.id}") do
        version, revision = fake_edit(post, user1.id, "Hello beautiful world", version: 1)
      end

    expect(messages.length).to eq(1)
    expect(messages.first.data[:version]).to eq(2)
    expect(version).to eq(2)

    # User 2 makes an edit based on version 2
    version, revision = fake_edit(post, user2.id, "Hello wonderful world", version: 2)
    expect(version).to eq(3)

    # Commit the changes
    SharedEditRevision.commit!(post.id)

    post.reload
    expect(post.raw).to eq("Hello wonderful world")

    # Check that both users are credited
    rev = post.revisions.order(:number).first
    reason = rev.modifications["edit_reason"][1].to_s
    expect(reason).to include(user1.username)
    expect(reason).to include(user2.username)

    # Check that the edit revision has a post_revision_id
    edit_rev = SharedEditRevision.where(post_id: post.id).order("version desc").first
    expect(edit_rev.post_revision_id).to eq(rev.id)
  end

  it "stores revisions without immediately updating the post" do
    user = Fabricate(:admin)
    post = Fabricate(:post, user: user, raw: "Hello world")

    SharedEditRevision.init!(post)

    new_content = "This is a test of the Yjs shared editing system"
    yjs_update = { content: new_content, timestamp: Time.current.to_i, version: 2 }.to_json
    SharedEditRevision.revise!(
      post_id: post.id,
      user_id: user.id,
      client_id: user.id.to_s,
      revision: yjs_update,
      version: 1,
    )

    # Post should not be updated until commit is called
    expect(post.reload.raw).to eq("Hello world")

    # After commit, post should be updated
    SharedEditRevision.commit!(post.id)
    expect(post.reload.raw).to eq(new_content)
  end
end
