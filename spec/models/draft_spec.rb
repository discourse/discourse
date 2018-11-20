require 'rails_helper'

describe Draft do
  before do
    @user = Fabricate(:user)
  end
  it "can get a draft by user" do
    Draft.set(@user, "test", 0, "data")
    expect(Draft.get(@user, "test", 0)).to eq "data"
  end

  it "uses the user id and key correctly" do
    Draft.set(@user, "test", 0, "data")
    expect(Draft.get(Fabricate.build(:coding_horror), "test", 0)).to eq nil
  end

  it "should overwrite draft data correctly" do
    Draft.set(@user, "test", 0, "data")
    Draft.set(@user, "test", 0, "new data")
    expect(Draft.get(@user, "test", 0)).to eq "new data"
  end

  it "should clear drafts on request" do
    Draft.set(@user, "test", 0, "data")
    Draft.clear(@user, "test", 0)
    expect(Draft.get(@user, "test", 0)).to eq nil
  end

  it "should disregard old draft if sequence decreases" do
    Draft.set(@user, "test", 0, "data")
    Draft.set(@user, "test", 1, "hello")
    Draft.set(@user, "test", 0, "foo")
    expect(Draft.get(@user, "test", 0)).to eq nil
    expect(Draft.get(@user, "test", 1)).to eq "hello"
  end

  it 'can cleanup old drafts' do
    user = Fabricate(:user)
    key = Draft::NEW_TOPIC

    Draft.set(user, key, 0, 'draft')
    Draft.cleanup!
    expect(Draft.count).to eq 1

    seq = DraftSequence.next!(user, key)

    Draft.set(user, key, seq, 'draft')
    DraftSequence.update_all('sequence = sequence + 1')

    Draft.cleanup!

    expect(Draft.count).to eq 0
    Draft.set(Fabricate(:user), Draft::NEW_TOPIC, seq + 1, 'draft')

    Draft.cleanup!

    expect(Draft.count).to eq 1

    # should cleanup drafts more than 180 days old
    SiteSetting.delete_drafts_older_than_n_days = 180

    Draft.last.update_columns(updated_at: 200.days.ago)
    Draft.cleanup!
    expect(Draft.count).to eq 0
  end

  describe '#stream' do
    let(:public_post) { Fabricate(:post) }
    let(:public_topic) { public_post.topic }

    let(:stream) do
      Draft.stream(user: @user)
    end

    it "should include the correct number of drafts in the stream" do
      Draft.set(@user, "test", 0, '{"reply":"hey.","action":"createTopic","title":"Hey"}')
      Draft.set(@user, "test2", 0, '{"reply":"howdy"}')
      expect(stream.count).to eq(2)
    end

    it "should include the right topic id in a draft reply in the stream" do
      Draft.set(@user, "topic_#{public_topic.id}", 0, '{"reply":"hi"}')
      draft_row = stream.first
      expect(draft_row.topic_id).to eq(public_topic.id)
    end

    it "should include the right draft username in the stream" do
      Draft.set(@user, "topic_#{public_topic.id}", 0, '{"reply":"hey"}')
      draft_row = stream.first
      expect(draft_row.draft_username).to eq(@user.username)
    end

  end

  context 'key expiry' do
    it 'nukes new topic draft after a topic is created' do
      u = Fabricate(:user)
      Draft.set(u, Draft::NEW_TOPIC, 0, 'my draft')
      _t = Fabricate(:topic, user: u)
      s = DraftSequence.current(u, Draft::NEW_TOPIC)
      expect(Draft.get(u, Draft::NEW_TOPIC, s)).to eq nil
      expect(Draft.count).to eq 0
    end

    it 'nukes new pm draft after a pm is created' do
      u = Fabricate(:user)
      Draft.set(u, Draft::NEW_PRIVATE_MESSAGE, 0, 'my draft')
      t = Fabricate(:topic, user: u, archetype: Archetype.private_message, category_id: nil)
      s = DraftSequence.current(t.user, Draft::NEW_PRIVATE_MESSAGE)
      expect(Draft.get(u, Draft::NEW_PRIVATE_MESSAGE, s)).to eq nil
    end

    it 'does not nuke new topic draft after a pm is created' do
      u = Fabricate(:user)
      Draft.set(u, Draft::NEW_TOPIC, 0, 'my draft')
      t = Fabricate(:topic, user: u, archetype: Archetype.private_message, category_id: nil)
      s = DraftSequence.current(t.user, Draft::NEW_TOPIC)
      expect(Draft.get(u, Draft::NEW_TOPIC, s)).to eq 'my draft'
    end

    it 'nukes the post draft when a post is created' do
      user = Fabricate(:user)
      topic = Fabricate(:topic)
      p = PostCreator.new(user, raw: Fabricate.build(:post).raw, topic_id: topic.id).create
      Draft.set(p.user, p.topic.draft_key, 0, 'hello')

      PostCreator.new(user, raw: Fabricate.build(:post).raw).create
      expect(Draft.get(p.user, p.topic.draft_key, DraftSequence.current(p.user, p.topic.draft_key))).to eq nil
    end

    it 'nukes the post draft when a post is revised' do
      p = Fabricate(:post)
      Draft.set(p.user, p.topic.draft_key, 0, 'hello')
      p.revise(p.user, raw: 'another test')
      s = DraftSequence.current(p.user, p.topic.draft_key)
      expect(Draft.get(p.user, p.topic.draft_key, s)).to eq nil
    end

    it 'increases revision each time you set' do
      u = User.first
      Draft.set(u, 'new_topic', 0, 'hello')
      Draft.set(u, 'new_topic', 0, 'goodbye')

      expect(Draft.find_draft(u, 'new_topic').revisions).to eq(2)
    end
  end
end
