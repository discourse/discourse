# encoding: UTF-8

require 'rails_helper'

describe SpamRulesEnforcer do

  describe 'auto-blocking users based on flagging' do
    before do
      SiteSetting.stubs(:flags_required_to_hide_post).returns(0) # never
      SiteSetting.stubs(:num_flags_to_block_new_user).returns(2)
      SiteSetting.stubs(:num_users_to_block_new_user).returns(2)
    end

    Given!(:admin)     { Fabricate(:admin) } # needed to send a system message
    Given!(:moderator) { Fabricate(:moderator) }
    Given(:user1)      { Fabricate(:user) }
    Given(:user2)      { Fabricate(:user) }

    context 'spammer is a new user' do
      Given(:spammer)  { Fabricate(:user, trust_level: TrustLevel[0]) }

      context 'spammer post is not flagged enough times' do
        Given!(:spam_post)  { create_post(user: spammer) }
        Given!(:spam_post2) { create_post(user: spammer) }
        When                { PostAction.act(user1, spam_post, PostActionType.types[:spam]) }
        Then                { expect(spam_post.reload).to_not be_hidden }

        context 'spam posts are flagged enough times, but not by enough users' do
          When { PostAction.act(user1, spam_post2, PostActionType.types[:spam]) }
          Then { expect(spam_post.reload).to_not be_hidden }
          And  { expect(spam_post2.reload).to_not be_hidden }
          And  { expect(spammer.reload).to_not be_blocked }
        end

        context 'one spam post is flagged enough times by enough users' do
          Given!(:another_topic)          { Fabricate(:topic) }
          Given!(:private_messages_count) { spammer.private_topics_count }
          Given!(:mod_pm_count)           { moderator.private_topics_count }

          When { PostAction.act(user2, spam_post, PostActionType.types[:spam]) }

          Invariant { expect(Guardian.new(spammer).can_create_topic?(nil)).to be false }
          Invariant { expect{PostCreator.create(spammer, {title: 'limited time offer for you', raw: 'better buy this stuff ok', archetype_id: 1})}.to raise_error(Discourse::InvalidAccess) }
          Invariant { expect(PostCreator.create(spammer, {topic_id: another_topic.id, raw: 'my reply is spam in your topic', archetype_id: 1})).to eq(nil) }

          Then { expect(spammer.reload).to be_blocked }
          And  { expect(spam_post.reload).to be_hidden }
          And  { expect(spam_post2.reload).to be_hidden }
          And  { expect(spammer.reload.private_topics_count).to eq(private_messages_count + 1) }


          # The following cases describe when a staff user takes some action, but the user
          # still won't be able to make posts.
          # A staff user needs to clear the blocked flag from the user record.

          context "a post's flags are cleared" do
            When { PostAction.clear_flags!(spam_post, admin); spammer.reload }
            Then { expect(spammer.reload).to be_blocked }
          end

          context "a post is deleted" do
            When { spam_post.trash!(moderator); spammer.reload }
            Then { expect(spammer.reload).to be_blocked }
          end

          context "spammer becomes trust level 1" do
            When { spammer.change_trust_level!(TrustLevel[1]); spammer.reload }
            Then { expect(spammer.reload).to be_blocked }
          end
        end

        context 'flags_required_to_hide_post takes effect too' do
          Given { SiteSetting.stubs(:flags_required_to_hide_post).returns(2) }
          When  { PostAction.act(user2, spam_post, PostActionType.types[:spam]) }
          Then  { expect(spammer.reload).to be_blocked }
          And   { expect(Guardian.new(spammer).can_create_topic?(nil)).to be false }
        end
      end
    end

    context "spammer has trust level basic" do
      Given(:spammer)  { Fabricate(:user, trust_level: TrustLevel[1]) }

      context 'one spam post is flagged enough times by enough users' do
        Given!(:spam_post)              { Fabricate(:post, user: spammer) }
        Given!(:private_messages_count) { spammer.private_topics_count }
        When { PostAction.act(user1, spam_post, PostActionType.types[:spam]) }
        When { PostAction.act(user2, spam_post, PostActionType.types[:spam]) }
        Then { expect(spam_post.reload).to_not be_hidden }
        And  { expect(Guardian.new(spammer).can_create_topic?(nil)).to be true }
        And  { expect{PostCreator.create(spammer, {title: 'limited time offer for you', raw: 'better buy this stuff ok', archetype_id: 1})}.to_not raise_error }
        And  { expect(spammer.reload.private_topics_count).to eq(private_messages_count) }
      end
    end

    [[:user, trust_level: TrustLevel[2]], [:admin], [:moderator]].each do |spammer_args|
      context "spammer is trusted #{spammer_args[0]}" do
        Given!(:spammer)                { Fabricate(*spammer_args) }
        Given!(:spam_post)              { Fabricate(:post, user: spammer) }
        Given!(:private_messages_count) { spammer.private_topics_count }
        When { PostAction.act(user1, spam_post, PostActionType.types[:spam]) }
        When { PostAction.act(user2, spam_post, PostActionType.types[:spam]) }
        Then { expect(spam_post.reload).to_not be_hidden }
      end
    end
  end
end
