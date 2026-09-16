# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20260915141510_move_edit_drafts_to_edit_post_keys.rb")

RSpec.describe MoveEditDraftsToEditPostKeys do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  fab!(:user)
  fab!(:post)

  def set_draft(key, data)
    Draft.set(user, key, DraftSequence.current(user, key), data.to_json)
  end

  def current_draft(key)
    Draft.get(user, key, DraftSequence.current(user, key))
  end

  it "moves edit drafts from the topic key to the post's edit key" do
    set_draft(post.topic.draft_key, { action: "edit", postId: post.id, reply: "edited" })

    described_class.new.up

    expect(current_draft(post.topic.draft_key)).to be_nil
    expect(JSON.parse(current_draft(post.edit_draft_key))["reply"]).to eq("edited")
  end

  it "moves shared draft edits" do
    set_draft(post.topic.draft_key, { action: "editSharedDraft", postId: post.id, reply: "edited" })

    described_class.new.up

    expect(JSON.parse(current_draft(post.edit_draft_key))["reply"]).to eq("edited")
  end

  it "aligns the draft with a sequence that already exists for the edit key" do
    DraftSequence.next!(user, post.edit_draft_key)
    DraftSequence.next!(user, post.edit_draft_key)
    set_draft(post.topic.draft_key, { action: "edit", postId: post.id, reply: "edited" })

    described_class.new.up

    expect(JSON.parse(current_draft(post.edit_draft_key))["reply"]).to eq("edited")
  end

  it "keeps a newer draft already saved under the edit key" do
    set_draft(post.topic.draft_key, { action: "edit", postId: post.id, reply: "legacy" })
    set_draft(post.edit_draft_key, { action: "edit", postId: post.id, reply: "newer" })

    described_class.new.up

    expect(Draft.where(user:).pluck(:draft_key)).to contain_exactly(post.edit_draft_key)
    expect(JSON.parse(current_draft(post.edit_draft_key))["reply"]).to eq("newer")
  end

  it "leaves reply drafts and unparseable drafts on the topic key" do
    other_topic = Fabricate(:topic)
    set_draft(post.topic.draft_key, { action: "reply", postId: post.id, reply: "reply" })
    Draft.set(user, other_topic.draft_key, 0, '{"action":"edit", broken')

    described_class.new.up

    expect(Draft.where(user:).pluck(:draft_key)).to contain_exactly(
      post.topic.draft_key,
      other_topic.draft_key,
    )
  end
end
