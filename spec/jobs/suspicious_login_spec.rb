require 'rails_helper'

describe Jobs::SuspiciousLogin do

  let(:user) { Fabricate(:moderator) }

  before do
    UserAuthToken.stubs(:login_location).with("1.1.1.1").returns("Location 1")
    UserAuthToken.stubs(:login_location).with("1.1.1.2").returns("Location 1")
    UserAuthToken.stubs(:login_location).with("1.1.2.1").returns("Location 2")
  end

  it "will not send an email on first login" do
    expect do
      described_class.new.execute(user_id: user.id, client_ip: "1.1.1.1")
    end.to_not change { Jobs::CriticalUserEmail.jobs.size }

    expect(UserAuthTokenLog.where(action: "suspicious").count).to eq(0)
  end

  it "will not send an email when user log in from a known location" do
    UserAuthTokenLog.create!(action: "generate", user_id: user.id, client_ip: "1.1.1.1")

    expect do
      described_class.new.execute(user_id: user.id, client_ip: "1.1.1.1")
      described_class.new.execute(user_id: user.id, client_ip: "1.1.1.2")
    end.to_not change { Jobs::CriticalUserEmail.jobs.size }

    expect(UserAuthTokenLog.where(action: "suspicious").count).to eq(0)
  end

  it "will send an email when user logs in from a new location" do
    UserAuthTokenLog.create!(action: "generate", user_id: user.id, client_ip: "1.1.1.1")

    described_class.new.execute(user_id: user.id, client_ip: "1.1.2.1")

    expect(UserAuthTokenLog.where(action: "suspicious").count).to eq(1)

    expect(Jobs::CriticalUserEmail.jobs.first["args"].first["type"])
      .to eq('suspicious_login')
  end

end
