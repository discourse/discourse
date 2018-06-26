require 'rails_helper'

describe UserSilencer do

  before do
    SystemMessage.stubs(:create)
  end

  describe 'silence' do
    let(:user) { Fabricate(:user) }
    let(:silencer) { UserSilencer.new(user) }
    subject(:silence_user) { silencer.silence }

    it 'silences the user' do
      u = Fabricate(:user)
      expect { UserSilencer.silence(u) }.to change { u.reload.silenced? }
    end

    it 'hides posts' do
      silencer.expects(:hide_posts)
      silence_user
    end

    context 'given a staff user argument' do
      it 'sends the correct message to the silenced user' do
        SystemMessage.unstub(:create)
        SystemMessage.expects(:create).with(user, :silenced_by_staff).returns(true)
        UserSilencer.silence(user, Fabricate.build(:admin))
      end
    end

    context 'not given a staff user argument' do
      it 'sends a default message to the user' do
        SystemMessage.unstub(:create)
        SystemMessage.expects(:create).with(user, :silenced_by_staff).returns(true)
        UserSilencer.silence(user, Fabricate.build(:admin))
      end
    end

    context 'given a message option' do
      it 'sends that message to the user' do
        SystemMessage.unstub(:create)
        SystemMessage.expects(:create).with(user, :the_custom_message).returns(true)
        UserSilencer.silence(user, Fabricate.build(:admin), message: :the_custom_message)
      end
    end

    it "doesn't send a pm if save fails" do
      user.stubs(:save).returns(false)
      SystemMessage.unstub(:create)
      SystemMessage.expects(:create).never
      silence_user
    end

    it "doesn't send a pm if the user is already silenced" do
      user.silenced_till = 1.year.from_now
      SystemMessage.unstub(:create)
      SystemMessage.expects(:create).never
      expect(silence_user).to eq(false)
    end

    it "logs it with context" do
      SystemMessage.stubs(:create)
      expect {
        UserSilencer.silence(user, Fabricate(:admin))
      }.to change { UserHistory.count }.by(1)
      expect(UserHistory.last.context).to be_present
    end
  end

  describe 'unsilence' do
    let(:user)             { stub_everything(save: true) }
    subject(:unsilence_user) { UserSilencer.unsilence(user, Fabricate.build(:admin)) }

    it 'unsilences the user' do
      u = Fabricate(:user, silenced_till: 1.year.from_now)
      expect { UserSilencer.unsilence(u) }.to change { u.reload.silenced? }
    end

    it 'sends a message to the user' do
      SystemMessage.unstub(:create)
      SystemMessage.expects(:create).with(user, :unsilenced).returns(true)
      unsilence_user
    end

    it "doesn't send a pm if save fails" do
      user.stubs(:save).returns(false)
      SystemMessage.unstub(:create)
      SystemMessage.expects(:create).never
      unsilence_user
    end

    it "logs it" do
      expect {
        unsilence_user
      }.to change { UserHistory.count }.by(1)
    end
  end

  describe 'hide_posts' do
    let(:user)    { Fabricate(:user, trust_level: 0) }
    let!(:post)   { Fabricate(:post, user: user) }
    subject       { UserSilencer.new(user) }

    it "hides all the user's posts" do
      subject.silence
      expect(post.reload).to be_hidden
    end

    it "hides the topic if the post was the first post" do
      subject.silence
      expect(post.topic.reload).to_not be_visible
    end

    it "doesn't hide posts if user is TL1" do
      user.trust_level = 1
      subject.silence
      expect(post.reload).to_not be_hidden
      expect(post.topic.reload).to be_visible
    end

    it "only hides posts from the past 24 hours" do
      old_post = Fabricate(:post, user: user, created_at: 2.days.ago)
      subject.silence
      expect(post.reload).to be_hidden
      expect(post.topic.reload).to_not be_visible
      old_post.reload
      expect(old_post).to_not be_hidden
      expect(old_post.topic).to be_visible
    end
  end

end
