# frozen_string_literal: true

require 'rails_helper'

describe Draft do

  fab!(:user) do
    Fabricate(:user)
  end

  fab!(:post) do
    Fabricate(:post)
  end

  context 'system user' do
    it "can not set drafts" do
      # fake a sequence
      DraftSequence.create!(user_id: Discourse.system_user.id, draft_key: "abc", sequence: 10)

      seq = Draft.set(Discourse.system_user, "abc", 0, { reply: 'hi' }.to_json)
      expect(seq).to eq(0)

      draft = Draft.get(Discourse.system_user, "abc", 0)
      expect(draft).to eq(nil)

      draft = Draft.get(Discourse.system_user, "abc", 1)
      expect(draft).to eq(nil)
    end
  end

  context 'backup_drafts_to_pm_length' do
    it "correctly backs up drafts to a personal message" do
      SiteSetting.backup_drafts_to_pm_length = 1

      draft = {
        reply: "this is a reply",
        random_key: "random"
      }

      seq = Draft.set(user, "xyz", 0, draft.to_json)
      draft["reply"] = "test" * 100

      half_grace = (SiteSetting.editing_grace_period / 2 + 1).seconds

      freeze_time half_grace.from_now
      seq = Draft.set(user, "xyz", seq, draft.to_json)

      draft_post = BackupDraftPost.find_by(user_id: user.id, key: "xyz").post

      expect(draft_post.revisions.count).to eq(0)

      freeze_time half_grace.from_now

      # this should trigger a post revision as 10 minutes have passed
      draft["reply"] = "hello"
      Draft.set(user, "xyz", seq, draft.to_json)

      draft_topic = BackupDraftTopic.find_by(user_id: user.id)
      expect(draft_topic.topic.posts_count).to eq(2)

      draft_post.reload
      expect(draft_post.revisions.count).to eq(1)
    end
  end

  it "can get a draft by user" do
    Draft.set(user, "test", 0, "data")
    expect(Draft.get(user, "test", 0)).to eq "data"
  end

  it "uses the user id and key correctly" do
    Draft.set(user, "test", 0, "data")
    expect(Draft.get(Fabricate.build(:coding_horror), "test", 0)).to eq nil
  end

  it "should overwrite draft data correctly" do
    seq = Draft.set(user, "test", 0, "data")
    seq = Draft.set(user, "test", seq, "new data")
    expect(Draft.get(user, "test", seq)).to eq "new data"
  end

  it "should increase the sequence on every save" do
    seq = Draft.set(user, "test", 0, "data")
    expect(seq).to eq(0)
    seq = Draft.set(user, "test", 0, "data")
    expect(seq).to eq(1)
  end

  it "should clear drafts on request" do
    Draft.set(user, "test", 0, "data")
    Draft.clear(user, "test", 0)
    expect(Draft.get(user, "test", 0)).to eq nil
  end

  it "should cross check with DraftSequence table" do

    Draft.set(user, "test", 0, "old")
    expect(Draft.get(user, "test", 0)).to eq "old"

    DraftSequence.next!(user, "test")
    seq = DraftSequence.next!(user, "test")
    expect(seq).to eq(2)

    expect do
      Draft.set(user, "test", seq - 1, "error")
    end.to raise_error(Draft::OutOfSequence)

    expect do
      Draft.set(user, "test", seq + 1, "error")
    end.to raise_error(Draft::OutOfSequence)

    Draft.set(user, "test", seq, "data")
    expect(Draft.get(user, "test", seq)).to eq "data"

    expect do
      expect(Draft.get(user, "test", seq - 1)).to eq "data"
    end.to raise_error(Draft::OutOfSequence)

    expect do
      expect(Draft.get(user, "test", seq + 1)).to eq "data"
    end.to raise_error(Draft::OutOfSequence)
  end

  it "should disregard old draft if sequence decreases" do
    Draft.set(user, "test", 0, "data")
    DraftSequence.next!(user, "test")
    Draft.set(user, "test", 1, "hello")

    expect do
      Draft.set(user, "test", 0, "foo")
    end.to raise_error(Draft::OutOfSequence)

    expect do
      Draft.get(user, "test", 0)
    end.to raise_error(Draft::OutOfSequence)

    expect(Draft.get(user, "test", 1)).to eq "hello"
  end

  it "should disregard draft sequence if force_save is true" do
    Draft.set(user, "test", 0, "data")
    DraftSequence.next!(user, "test")
    Draft.set(user, "test", 1, "hello")

    seq = Draft.set(user, "test", 0, "foo", nil, force_save: true)
    expect(seq).to eq(2)
  end

  it 'can cleanup old drafts' do
    key = Draft::NEW_TOPIC

    Draft.set(user, key, 0, 'draft')
    Draft.cleanup!
    expect(Draft.count).to eq 1
    expect(user.user_stat.draft_count).to eq(1)

    seq = DraftSequence.next!(user, key)

    Draft.set(user, key, seq, 'draft')
    DraftSequence.update_all('sequence = sequence + 1')

    Draft.cleanup!

    expect(Draft.count).to eq 0
    expect(user.reload.user_stat.draft_count).to eq(0)

    Draft.set(Fabricate(:user), Draft::NEW_TOPIC, 0, 'draft')

    Draft.cleanup!

    expect(Draft.count).to eq 1

    # should cleanup drafts more than 180 days old
    SiteSetting.delete_drafts_older_than_n_days = 180

    Draft.last.update_columns(updated_at: 200.days.ago)
    Draft.cleanup!
    expect(Draft.count).to eq 0
  end

  it 'updates draft count when a draft is created or destroyed' do
    Draft.set(Fabricate(:user), Draft::NEW_TOPIC, 0, "data")

    messages = MessageBus.track_publish("/user") do
      Draft.set(user, Draft::NEW_TOPIC, 0, "data")
    end

    expect(messages.first.data[:draft_count]).to eq(1)
    expect(messages.first.data[:has_topic_draft]).to eq(true)

    messages = MessageBus.track_publish("/user") do
      Draft.where(user: user).destroy_all
    end

    expect(messages.first.data[:draft_count]).to eq(0)
    expect(messages.first.data[:has_topic_draft]).to eq(false)
  end

  describe '#stream' do
    fab!(:public_post) { Fabricate(:post) }
    let(:public_topic) { public_post.topic }

    let(:stream) do
      Draft.stream(user: user)
    end

    it "should include the correct number of drafts in the stream" do
      Draft.set(user, "test", 0, '{"reply":"hey.","action":"createTopic","title":"Hey"}')
      Draft.set(user, "test2", 0, '{"reply":"howdy"}')
      expect(stream.count).to eq(2)
    end

    it "should include the right topic id in a draft reply in the stream" do
      Draft.set(user, "topic_#{public_topic.id}", 0, '{"reply":"hi"}')
      draft_row = stream.first
      expect(draft_row.topic_id).to eq(public_topic.id)
    end

    it "should include the right draft username in the stream" do
      Draft.set(user, "topic_#{public_topic.id}", 0, '{"reply":"hey"}')
      draft_row = stream.first
      expect(draft_row.user.username).to eq(user.username)
    end

  end

  context 'key expiry' do
    it 'nukes new topic draft after a topic is created' do
      Draft.set(user, Draft::NEW_TOPIC, 0, 'my draft')
      _t = Fabricate(:topic, user: user, advance_draft: true)
      s = DraftSequence.current(user, Draft::NEW_TOPIC)
      expect(Draft.get(user, Draft::NEW_TOPIC, s)).to eq nil
      expect(Draft.count).to eq 0
    end

    it 'nukes new pm draft after a pm is created' do
      Draft.set(user, Draft::NEW_PRIVATE_MESSAGE, 0, 'my draft')
      t = Fabricate(:topic, user: user, archetype: Archetype.private_message, category_id: nil, advance_draft: true)
      s = DraftSequence.current(t.user, Draft::NEW_PRIVATE_MESSAGE)
      expect(Draft.get(user, Draft::NEW_PRIVATE_MESSAGE, s)).to eq nil
    end

    it 'does not nuke new topic draft after a pm is created' do
      Draft.set(user, Draft::NEW_TOPIC, 0, 'my draft')
      t = Fabricate(:topic, user: user, archetype: Archetype.private_message, category_id: nil)
      s = DraftSequence.current(t.user, Draft::NEW_TOPIC)
      expect(Draft.get(user, Draft::NEW_TOPIC, s)).to eq 'my draft'
    end

    it 'nukes the post draft when a post is created' do
      topic = Fabricate(:topic)

      Draft.set(user, topic.draft_key, 0, 'hello')

      p = PostCreator.new(user, raw: Fabricate.build(:post).raw, topic_id: topic.id, advance_draft: true).create

      expect(Draft.get(p.user, p.topic.draft_key, DraftSequence.current(p.user, p.topic.draft_key))).to eq nil
    end

    it 'nukes the post draft when a post is revised' do
      Draft.set(post.user, post.topic.draft_key, 0, 'hello')
      post.revise(post.user, raw: 'another test')
      s = DraftSequence.current(post.user, post.topic.draft_key)
      expect(Draft.get(post.user, post.topic.draft_key, s)).to eq nil
    end

    it 'increases revision each time you set' do
      Draft.set(user, 'new_topic', 0, 'hello')
      Draft.set(user, 'new_topic', 0, 'goodbye')

      expect(Draft.find_by(user_id: user.id, draft_key: 'new_topic').revisions).to eq(2)
    end

    it 'handles owner switching gracefully' do
      draft_seq = Draft.set(user, 'new_topic', 0, 'hello', _owner = 'ABCDEF')
      expect(draft_seq).to eq(0)

      draft_seq = Draft.set(user, 'new_topic', 0, 'hello world', _owner = 'HIJKL')
      expect(draft_seq).to eq(1)

      draft_seq = Draft.set(user, 'new_topic', 1, 'hello world', _owner = 'HIJKL')
      expect(draft_seq).to eq(2)
    end

    it 'can correctly preload drafts' do
      Draft.set(user, "#{Draft::EXISTING_TOPIC}#{post.topic_id}", 0, { raw: 'hello', postId: post.id }.to_json)

      drafts = Draft.where(user_id: user.id).to_a

      Draft.preload_data(drafts, user)

      expect(drafts[0].topic_preloaded?).to eq(true)
      expect(drafts[0].topic.id).to eq(post.topic_id)

      expect(drafts[0].post_preloaded?).to eq(true)
      expect(drafts[0].post.id).to eq(post.id)
    end

  end
end
