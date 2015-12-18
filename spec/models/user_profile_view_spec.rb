require 'rails_helper'

RSpec.describe UserProfileView do
  let(:user) { Fabricate(:user) }
  let(:other_user) { Fabricate(:user) }
  let(:user_profile_id) { user.user_profile.id }

  def add(user_profile_id, ip, user_id=nil, at=nil)
    described_class.add(user_profile_id, ip, user_id, at, true)
  end

  it "should increase user's profile view count" do
    expect{ add(user_profile_id, '1.1.1.1') }.to change{ described_class.count }.by(1)
    expect(user.user_profile.reload.views).to eq(1)
    expect{ add(user_profile_id, '1.1.1.1', other_user.id) }.to change{ described_class.count }.by(1)

    user_profile = user.user_profile.reload
    expect(user_profile.views).to eq(2)
    expect(user_profile.user_profile_views).to eq(described_class.all)
  end

  it "should not create duplicated profile view for anon user" do
    time = Time.zone.now

    2.times do
      add(user_profile_id, '1.1.1.1', nil, time)
      expect(described_class.count).to eq(1)
    end
  end

  it "should not create duplicated profile view for signed in user" do
    time = Time.zone.now

    ['1.1.1.1', '2.2.2.2'].each do |ip|
      add(user_profile_id, ip, other_user.id, time)
      expect(described_class.count).to eq(1)
    end
  end
end
