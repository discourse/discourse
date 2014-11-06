require 'spec_helper'

describe Draft do
  before do
    @user = Fabricate(:user)
  end
  it "can get a draft by user" do
    Draft.set(@user, "test", 0, "data")
    Draft.get(@user, "test", 0).should == "data"
  end

  it "uses the user id and key correctly" do
    Draft.set(@user, "test", 0,"data")
    Draft.get(Fabricate.build(:coding_horror), "test", 0).should == nil
  end

  it "should overwrite draft data correctly" do
    Draft.set(@user, "test", 0, "data")
    Draft.set(@user, "test", 0, "new data")
    Draft.get(@user, "test", 0).should == "new data"
  end

  it "should clear drafts on request" do
    Draft.set(@user, "test", 0, "data")
    Draft.clear(@user, "test", 0)
    Draft.get(@user, "test", 0).should == nil
  end

  it "should disregard old draft if sequence decreases" do
    Draft.set(@user, "test", 0, "data")
    Draft.set(@user, "test", 1, "hello")
    Draft.set(@user, "test", 0, "foo")
    Draft.get(@user, "test", 0).should == nil
    Draft.get(@user, "test", 1).should == "hello"
  end


  context 'key expiry' do
    it 'nukes new topic draft after a topic is created' do
      u = Fabricate(:user)
      Draft.set(u, Draft::NEW_TOPIC, 0, 'my draft')
      _t = Fabricate(:topic, user: u)
      s = DraftSequence.current(u, Draft::NEW_TOPIC)
      Draft.get(u, Draft::NEW_TOPIC, s).should == nil
    end

    it 'nukes new pm draft after a pm is created' do
      u = Fabricate(:user)
      Draft.set(u, Draft::NEW_PRIVATE_MESSAGE, 0, 'my draft')
      t = Fabricate(:topic, user: u, archetype: Archetype.private_message, category_id: nil)
      s = DraftSequence.current(t.user, Draft::NEW_PRIVATE_MESSAGE)
      Draft.get(u, Draft::NEW_PRIVATE_MESSAGE, s).should == nil
    end

    it 'does not nuke new topic draft after a pm is created' do
      u = Fabricate(:user)
      Draft.set(u, Draft::NEW_TOPIC, 0, 'my draft')
      t = Fabricate(:topic, user: u, archetype: Archetype.private_message, category_id: nil)
      s = DraftSequence.current(t.user, Draft::NEW_TOPIC)
      Draft.get(u, Draft::NEW_TOPIC, s).should == 'my draft'
    end

    it 'nukes the post draft when a post is created' do
      user = Fabricate(:user)
      topic = Fabricate(:topic)
      p = PostCreator.new(user, raw: Fabricate.build(:post).raw, topic_id: topic.id).create
      Draft.set(p.user, p.topic.draft_key, 0,'hello')

      PostCreator.new(user, raw: Fabricate.build(:post).raw).create
      Draft.get(p.user, p.topic.draft_key, DraftSequence.current(p.user, p.topic.draft_key)).should == nil
    end

    it 'nukes the post draft when a post is revised' do
      p = Fabricate(:post)
      Draft.set(p.user, p.topic.draft_key, 0,'hello')
      p.revise(p.user, { raw: 'another test' })
      s = DraftSequence.current(p.user, p.topic.draft_key)
      Draft.get(p.user, p.topic.draft_key, s).should == nil
    end

    it 'increases the sequence number when a post is revised' do
    end
  end
end
