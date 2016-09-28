require 'rails_helper'

describe Jobs::PurgeInactive do
  let!(:user) { Fabricate(:user) }
  let!(:inactive) { Fabricate(:user, active: false) }
  let!(:inactive_old) { Fabricate(:user, active: false, created_at: 1.month.ago) }

  it 'should only remove old, unactivated users' do
    Jobs::PurgeInactive.new.execute(1)
    all_users = User.all
    expect(all_users.include?(user)).to eq(true)
    expect(all_users.include?(inactive)).to eq(true)
    expect(all_users.include?(inactive_old)).to eq(false)
  end
end
