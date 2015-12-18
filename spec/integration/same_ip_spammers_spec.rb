# encoding: UTF-8

require 'rails_helper'

describe SpamRulesEnforcer do

  Given(:ip_address)  { '182.189.119.174' }
  Given!(:spammer1)   { Fabricate(:user, ip_address: ip_address) }
  Given!(:spammer2)   { Fabricate(:user, ip_address: ip_address) }
  Given(:spammer3)    { Fabricate(:user, ip_address: ip_address) }

  context 'flag_sockpuppets is disabled' do
    Given                 { SiteSetting.stubs(:flag_sockpuppets).returns(false) }
    Given!(:first_post)   { create_post(user: spammer1) }
    Given!(:second_post)  { create_post(user: spammer2, topic: first_post.topic) }

    Then { expect(first_post.reload.spam_count).to  eq(0) }
    And  { expect(second_post.reload.spam_count).to eq(0) }
  end

  context 'flag_sockpuppets is enabled' do
    Given { SiteSetting.stubs(:flag_sockpuppets).returns(true) }

    context 'first spammer starts a topic' do
      Given!(:first_post) { create_post(user: spammer1) }

      context 'second spammer replies' do
        Given!(:second_post)  { create_post(user: spammer2, topic: first_post.topic) }

        Then { expect(first_post.reload.spam_count).to  eq(1) }
        And  { expect(second_post.reload.spam_count).to eq(1) }

        context 'third spam post' do
          Given!(:third_post) { create_post(user: spammer3, topic: first_post.topic) }

          Then { expect(first_post.reload.spam_count).to  eq(1) }
          And  { expect(second_post.reload.spam_count).to eq(1) }
          And  { expect(third_post.reload.spam_count).to  eq(1) }
        end
      end
    end

    context 'first user is not new' do
      Given!(:old_user) { Fabricate(:user, ip_address: ip_address, created_at: 2.days.ago, trust_level: TrustLevel[1]) }

      context 'first user starts a topic' do
        Given!(:first_post) { create_post(user: old_user) }

        context 'a reply by a new user at the same IP address' do
          Given!(:second_post)  { create_post(user: spammer2, topic: first_post.topic) }

          Then { expect(first_post.reload.spam_count).to  eq(0) }
          And  { expect(second_post.reload.spam_count).to eq(1) }
        end
      end
    end
  end

end
