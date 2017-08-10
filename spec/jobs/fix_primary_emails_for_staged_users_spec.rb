require 'rails_helper'

RSpec.describe Jobs::FixPrimaryEmailsForStagedUsers do
  it 'should clean up duplicated staged users' do
    common_email = 'test@reply'

    staged_user = Fabricate(:user, staged: true, active: false)
    staged_user2 = Fabricate(:user, staged: true, active: false)
    staged_user3 = Fabricate(:user, staged: true, active: false)

    [staged_user, staged_user2, staged_user3].each do |user|
      user.email_tokens = [Fabricate.create(:email_token, email: common_email, user: user)]
    end

    active_user = Fabricate(:coding_horror)

    UserEmail.delete_all

    expect { described_class.new.execute_onceoff({}) }
      .to change { User.count }.by(-2)

    expect(User.all).to contain_exactly(Discourse.system_user, staged_user, active_user)
    expect(staged_user.reload.email).to eq(common_email)
  end
end
