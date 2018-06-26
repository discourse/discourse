# encoding: UTF-8

require 'rails_helper'

describe SpamRulesEnforcer do

  describe 'auto-silenceing users based on flagging' do
    let!(:admin)     { Fabricate(:admin) } # needed to send a system message
    let!(:moderator) { Fabricate(:moderator) }
    let(:user1)      { Fabricate(:user) }
    let(:user2)      { Fabricate(:user) }

    before do
      SiteSetting.flags_required_to_hide_post = 0
      SiteSetting.num_spam_flags_to_silence_new_user = 2
      SiteSetting.num_users_to_silence_new_user = 2
    end

    context 'spammer is a new user' do
      let(:spammer)  { Fabricate(:user, trust_level: TrustLevel[0]) }

      context 'spammer post is not flagged enough times' do
        let!(:spam_post)  { create_post(user: spammer) }
        let!(:spam_post2) { create_post(user: spammer) }

        before do
          PostAction.act(user1, spam_post, PostActionType.types[:spam])
        end

        it 'should not hide the post' do
          expect(spam_post.reload).to_not be_hidden
        end

        context 'spam posts are flagged enough times, but not by enough users' do
          it 'should not hide the post' do
            PostAction.act(user1, spam_post2, PostActionType.types[:spam])

            expect(spam_post.reload).to_not be_hidden
            expect(spam_post2.reload).to_not be_hidden
            expect(spammer.reload).to_not be_silenced
          end
        end

        context 'one spam post is flagged enough times by enough users' do
          let!(:another_topic)          { Fabricate(:topic) }
          let!(:private_messages_count) { spammer.private_topics_count }
          let!(:mod_pm_count)           { moderator.private_topics_count }

          before do
            PostAction.act(user2, spam_post, PostActionType.types[:spam])

            expect(Guardian.new(spammer).can_create_topic?(nil)).to be(false)
            expect { PostCreator.create(spammer, title: 'limited time offer for you', raw: 'better buy this stuff ok', archetype_id: 1) }.to raise_error(Discourse::InvalidAccess)
            expect(PostCreator.create(spammer, topic_id: another_topic.id, raw: 'my reply is spam in your topic', archetype_id: 1)).to eq(nil)
          end

          it 'should hide the posts' do
            expect(spammer.reload).to be_silenced
            expect(spam_post.reload).to be_hidden
            expect(spam_post2.reload).to be_hidden
            expect(spammer.reload.private_topics_count).to eq(private_messages_count + 1)
          end

          # The following cases describe when a staff user takes some action, but the user
          # still won't be able to make posts.
          # A staff user needs to clear the silenced flag from the user record.

          context "a post's flags are cleared" do
            it 'should silence the spammer' do
              PostAction.clear_flags!(spam_post, admin); spammer.reload
              expect(spammer.reload).to be_silenced
            end
          end

          context "a post is deleted" do
            it 'should silence the spammer' do
              spam_post.trash!(moderator); spammer.reload
              expect(spammer.reload).to be_silenced
            end
          end

          context "spammer becomes trust level 1" do
            it 'should silence the spammer' do
              spammer.change_trust_level!(TrustLevel[1]); spammer.reload
              expect(spammer.reload).to be_silenced
            end
          end
        end

        context 'flags_required_to_hide_post takes effect too' do
          it 'should silence the spammer' do
            SiteSetting.flags_required_to_hide_post = 2
            PostAction.act(user2, spam_post, PostActionType.types[:spam])
            expect(spammer.reload).to be_silenced
            expect(Guardian.new(spammer).can_create_topic?(nil)).to be false
          end
        end
      end
    end

    context "spammer has trust level basic" do
      let(:spammer)  { Fabricate(:user, trust_level: TrustLevel[1]) }

      context 'one spam post is flagged enough times by enough users' do
        let!(:spam_post)              { Fabricate(:post, user: spammer) }
        let!(:private_messages_count) { spammer.private_topics_count }

        it 'should not allow spammer to create new posts' do
          PostAction.act(user1, spam_post, PostActionType.types[:spam])
          PostAction.act(user2, spam_post, PostActionType.types[:spam])

          expect(spam_post.reload).to_not be_hidden
          expect(Guardian.new(spammer).can_create_topic?(nil)).to be(true)
          expect { PostCreator.create(spammer, title: 'limited time offer for you', raw: 'better buy this stuff ok', archetype_id: 1) }.to_not raise_error
          expect(spammer.reload.private_topics_count).to eq(private_messages_count)
        end
      end
    end

    [[:user, trust_level: TrustLevel[2]], [:admin], [:moderator]].each do |spammer_args|
      context "spammer is trusted #{spammer_args[0]}" do
        let!(:spammer)                { Fabricate(*spammer_args) }
        let!(:spam_post)              { Fabricate(:post, user: spammer) }
        let!(:private_messages_count) { spammer.private_topics_count }

        it 'should not hide the post' do
          PostAction.act(user1, spam_post, PostActionType.types[:spam])
          PostAction.act(user2, spam_post, PostActionType.types[:spam])

          expect(spam_post.reload).to_not be_hidden
        end
      end
    end
  end
end
