# frozen_string_literal: true

require 'rails_helper'

describe SpamRule::AutoSilence do

  before do
    SiteSetting.hide_post_sensitivity = Reviewable.sensitivity[:disabled]
    Reviewable.set_priorities(high: 4.0)
    SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivity[:low]
    SiteSetting.num_users_to_silence_new_user = 2
  end

  describe 'perform' do
    let(:user) { Fabricate.build(:newuser) }
    let(:post) { Fabricate(:post, user: user) }
    subject { described_class.new(post.user) }

    it 'takes no action if user should not be silenced' do
      subject.perform
      expect(post.user.reload).not_to be_silenced
    end

    it 'delivers punishment when user should be silenced' do
      Reviewable.set_priorities(high: 2.0)
      SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivity[:low]
      SiteSetting.num_users_to_silence_new_user = 1
      PostActionCreator.spam(Discourse.system_user, post)
      subject.perform
      expect(post.user.reload).to be_silenced
    end
  end

  describe 'total_spam_score' do
    let(:post) { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }
    let(:flagger) { Fabricate(:user) }
    subject { enforcer.user_spam_stats.total_spam_score }

    it 'returns 0 when there are no flags' do
      expect(subject).to eq(0)
    end

    it 'returns 0 when there is one flag that has a reason other than spam' do
      PostActionCreator.off_topic(flagger, post)
      expect(subject).to eq(0)
    end

    it 'returns the score when there are two flags with spam as the reason' do
      PostActionCreator.spam(Fabricate(:user), post)
      PostActionCreator.spam(Fabricate(:user), post)
      expect(subject).to eq(4.0)
    end

    it 'returns the score when there are two spam flags, each on a different post' do
      PostActionCreator.spam(Fabricate(:user), post)
      PostActionCreator.spam(Fabricate(:user), Fabricate(:post, user: post.user))
      expect(subject).to eq(4.0)
    end
  end

  describe 'spam_user_count' do
    let(:post)     { Fabricate(:post) }
    let(:enforcer) { described_class.new(post.user) }
    subject        { enforcer.user_spam_stats.spam_user_count }

    it 'returns 0 when there are no flags' do
      expect(subject).to eq(0)
    end

    it 'returns 0 when there is one flag that has a reason other than spam' do
      Fabricate(:flag, post: post, post_action_type_id: PostActionType.types[:off_topic])
      expect(subject).to eq(0)
    end

    it 'returns 1 when there is one spam flag' do
      PostActionCreator.spam(Fabricate(:user), post)
      expect(subject).to eq(1)
    end

    it 'returns 2 when there are two spam flags from 2 users' do
      PostActionCreator.spam(Fabricate(:user), post)
      PostActionCreator.spam(Fabricate(:user), post)
      expect(subject).to eq(2)
    end

    it 'returns 1 when there are two spam flags on two different posts from 1 user' do
      flagger = Fabricate(:user)
      PostActionCreator.spam(flagger, post)
      PostActionCreator.spam(flagger, Fabricate(:post, user: post.user))
      expect(subject).to eq(1)
    end
  end

  describe 'silence_user' do
    let!(:admin)  { Fabricate(:admin) } # needed for SystemMessage
    let(:user)    { Fabricate(:user) }
    let!(:post)   { Fabricate(:post, user: user) }
    subject       { described_class.new(user) }

    context 'user is not silenced' do
      it 'prevents the user from making new posts' do
        subject.silence_user
        expect(user).to be_silenced
        expect(Guardian.new(user).can_create_post?(nil)).to be_falsey
      end

      context "with a moderator" do
        let!(:moderator) { Fabricate(:moderator) }

        it 'sends private message to moderators' do
          SiteSetting.notify_mods_when_user_silenced = true
          subject.silence_user
          expect(subject.group_message).to be_present
        end

        it "doesn't send a pm to moderators if notify_mods_when_user_silenced is false" do
          SiteSetting.notify_mods_when_user_silenced = false
          subject.silence_user
          expect(subject.group_message).to be_blank
        end
      end
    end

    context 'user is already silenced' do
      before do
        UserSilencer.silence(user)
      end

      it "doesn't send a pm to moderators if the user is already silenced" do
        subject.silence_user
        expect(subject.group_message).to be_blank
      end
    end
  end

  describe 'autosilenced?' do
    let(:user) { Fabricate(:newuser) }
    let(:flagger) { Fabricate(:user) }
    let(:flagger2) { Fabricate(:user) }
    let(:post) { Fabricate(:post, user: user) }
    let(:post2) { Fabricate(:post, user: user) }

    context "higher trust levels or staff" do
      it "should not autosilence any of them" do
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger2, post)

        enforcer = described_class.new(user)
        expect(enforcer.should_autosilence?).to eq(true)

        user.trust_level = 1
        expect(enforcer.should_autosilence?).to eq(false)

        user.trust_level = 2
        expect(enforcer.should_autosilence?).to eq(false)

        user.trust_level = 3
        expect(enforcer.should_autosilence?).to eq(false)

        user.trust_level = 4
        expect(enforcer.should_autosilence?).to eq(false)

        user.trust_level = 0
        user.moderator = true
        expect(enforcer.should_autosilence?).to eq(false)

        user.moderator = false
        user.admin = true
        expect(enforcer.should_autosilence?).to eq(false)
      end
    end

    context 'new user' do
      subject { described_class.new(user) }
      let(:stats) { subject.user_spam_stats }

      it 'returns false if there are no spam flags' do
        expect(stats.total_spam_score).to eq(0)
        expect(stats.spam_user_count).to eq(0)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if there are not received enough flags' do
        PostActionCreator.spam(flagger, post)
        expect(stats.total_spam_score).to eq(2.0)
        expect(stats.spam_user_count).to eq(1)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if there have not been enough users' do
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger, post2)
        expect(stats.total_spam_score).to eq(4.0)
        expect(stats.spam_user_count).to eq(1)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if silence_new_user_sensitivity is disabled' do
        SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivity[:disabled]
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger2, post)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns false if num_users_to_silence_new_user is 0' do
        SiteSetting.num_users_to_silence_new_user = 0
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger2, post)
        expect(subject.should_autosilence?).to eq(false)
      end

      it 'returns true when there are enough flags from enough users' do
        PostActionCreator.spam(flagger, post)
        PostActionCreator.spam(flagger2, post)
        expect(stats.total_spam_score).to eq(4.0)
        expect(stats.spam_user_count).to eq(2)
        expect(subject.should_autosilence?).to eq(true)
      end
    end

    context "silenced, but has higher trust level now" do
      let(:user)  { Fabricate(:user, silenced_till: 1.year.from_now, trust_level: TrustLevel[1]) }
      subject     { described_class.new(user) }

      it 'returns false' do
        expect(subject.should_autosilence?).to eq(false)
      end
    end
  end
end
