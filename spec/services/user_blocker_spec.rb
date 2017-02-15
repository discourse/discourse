require 'rails_helper'

describe UserBlocker do

  before do
    SystemMessage.stubs(:create)
  end

  describe 'block' do
    let(:user)           { stub_everything(save: true) }
    let(:blocker)        { UserBlocker.new(user) }
    subject(:block_user) { blocker.block }

    it 'blocks the user' do
      u = Fabricate(:user)
      expect { UserBlocker.block(u) }.to change { u.reload.blocked? }
    end

    it 'hides posts' do
      blocker.expects(:hide_posts)
      block_user
    end

    context 'given a staff user argument' do
      it 'sends the correct message to the blocked user' do
        SystemMessage.unstub(:create)
        SystemMessage.expects(:create).with(user, :blocked_by_staff).returns(true)
        UserBlocker.block(user, Fabricate.build(:admin))
      end
    end

    context 'not given a staff user argument' do
      it 'sends a default message to the user' do
        SystemMessage.unstub(:create)
        SystemMessage.expects(:create).with(user, :blocked_by_staff).returns(true)
        UserBlocker.block(user, Fabricate.build(:admin))
      end
    end

    context 'given a message option' do
      it 'sends that message to the user' do
        SystemMessage.unstub(:create)
        SystemMessage.expects(:create).with(user, :the_custom_message).returns(true)
        UserBlocker.block(user, Fabricate.build(:admin), {message: :the_custom_message})
      end
    end

    it "doesn't send a pm if save fails" do
      user.stubs(:save).returns(false)
      SystemMessage.unstub(:create)
      SystemMessage.expects(:create).never
      block_user
    end

    it "doesn't send a pm if the user is already blocked" do
      user.stubs(:blocked?).returns(true)
      SystemMessage.unstub(:create)
      SystemMessage.expects(:create).never
      expect(block_user).to eq(false)
    end

    it "logs it with context" do
      SystemMessage.stubs(:create).returns(Fabricate.build(:post))
      expect {
        UserBlocker.block(user, Fabricate(:admin))
      }.to change { UserHistory.count }.by(1)
      expect(UserHistory.last.context).to be_present
    end
  end

  describe 'unblock' do
    let(:user)             { stub_everything(save: true) }
    subject(:unblock_user) { UserBlocker.unblock(user, Fabricate.build(:admin)) }

    it 'unblocks the user' do
      u = Fabricate(:user, blocked: true)
      expect { UserBlocker.unblock(u) }.to change { u.reload.blocked? }
    end

    it 'sends a message to the user' do
      SystemMessage.unstub(:create)
      SystemMessage.expects(:create).with(user, :unblocked).returns(true)
      unblock_user
    end

    it "doesn't send a pm if save fails" do
      user.stubs(:save).returns(false)
      SystemMessage.unstub(:create)
      SystemMessage.expects(:create).never
      unblock_user
    end

    it "logs it" do
      expect {
        unblock_user
      }.to change { UserHistory.count }.by(1)
    end
  end

  describe 'hide_posts' do
    let(:user)    { Fabricate(:user, trust_level: 0) }
    let!(:post)   { Fabricate(:post, user: user) }
    subject       { UserBlocker.new(user) }

    it "hides all the user's posts" do
      subject.block
      expect(post.reload).to be_hidden
    end

    it "hides the topic if the post was the first post" do
      subject.block
      expect(post.topic.reload).to_not be_visible
    end

    it "doesn't hide posts if user is TL1" do
      user.trust_level = 1
      subject.block
      expect(post.reload).to_not be_hidden
      expect(post.topic.reload).to be_visible
    end

    it "only hides posts from the past 24 hours" do
      old_post = Fabricate(:post, user: user, created_at: 2.days.ago)
      subject.block
      expect(post.reload).to be_hidden
      expect(post.topic.reload).to_not be_visible
      old_post.reload
      expect(old_post).to_not be_hidden
      expect(old_post.topic).to be_visible
    end
  end

end
