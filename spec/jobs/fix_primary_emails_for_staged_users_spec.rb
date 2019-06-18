# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::FixPrimaryEmailsForStagedUsers do
  it 'should clean up duplicated staged users' do
    common_email = 'test@reply'

    staged_user = Fabricate(:user, staged: true, active: false)
    staged_user2 = Fabricate(:user, staged: true, active: false)
    staged_user3 = Fabricate(:user, staged: true, active: false)

    post1 = Fabricate(:post, user: staged_user2)
    post2 = Fabricate(:post, user: staged_user2)
    post3 = Fabricate(:post, user: staged_user3)

    [staged_user, staged_user2, staged_user3].each do |user|
      user.email_tokens = [Fabricate.create(:email_token, email: common_email, user: user)]
    end

    active_user = Fabricate(:coding_horror)

    UserEmail.delete_all

    # since we removing `user_emails` table the `user.primary_email` value will be nil.
    # it will raise error in https://github.com/discourse/discourse/blob/d0b027d88deeabf8bc105419f7d3fae0087091cd/app/models/user.rb#L942
    WebHook.stubs(:generate_payload).returns(nil)

    expect { described_class.new.execute_onceoff({}) }
      .to change { User.count }.by(-2)
      .and change { staged_user.posts.count }.by(3)

    expect(User.where('id > -2')).to contain_exactly(Discourse.system_user, staged_user, active_user)
    expect(staged_user.posts.all).to contain_exactly(post1, post2, post3)
    expect(staged_user.reload.email).to eq(common_email)
  end
end
