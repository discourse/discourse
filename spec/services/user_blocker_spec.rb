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

      # TODO: it 'logs the action'
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

    # TODO: it 'logs the action'
  end

  describe 'hide_posts' do
    let(:user)    { Fabricate(:user) }
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
  end

end
