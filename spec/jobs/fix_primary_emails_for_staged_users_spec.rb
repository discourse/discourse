require 'rails_helper'

RSpec.describe Jobs::FixPrimaryEmailsForStagedUsers do
  let(:common_email)  { 'test@reply' }
  let(:staged_user)   { Fabricate(:user, staged: true, active: false) }
  let(:staged_user2)  { Fabricate(:user, staged: true, active: false) }
  let(:staged_user3)  { Fabricate(:user, staged: true, active: false) }
  let(:active_user)   { Fabricate(:coding_horror) }

  before do
    [staged_user, staged_user2, staged_user3].each do |user|
      user.email_tokens = [Fabricate.create(:email_token, email: common_email, user: user)]
    end

    UserEmail.delete_all
  end

  it 'should clean up duplicated staged users' do
    expect { described_class.new.execute_onceoff({}) }
      .to change { User.count }.by(-2)

    expect(User.all).to contain_exactly(Discourse.system_user, staged_user, active_user)
    expect(staged_user.reload.email).to eq(common_email)
  end

  it 'should move posts owned by duplicate users to the original' do
    post1 = Fabricate(:post, user: staged_user2)
    post2 = Fabricate(:post, user: staged_user2)
    post3 = Fabricate(:post, user: staged_user3)

    expect { described_class.new.execute_onceoff({}) }
      .to change { staged_user.posts.count }.by(+3)

    expect(staged_user.posts.all).to contain_exactly(post1, post2, post3)
  end
end
