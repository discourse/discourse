require 'rails_helper'

describe Jobs::SuspiciousLogin do

  let(:user) { Fabricate(:moderator) }

  let(:zurich) { [47.3686498, 8.5391825] } # Zurich, Switzerland
  let(:bern) { [46.947922, 7.444608] }  # Bern, Switzerland
  let(:london) { [51.5073509, -0.1277583] } # London, United Kingdom

  before do
    UserAuthToken.stubs(:login_location).with("1.1.1.1").returns(zurich)
    UserAuthToken.stubs(:login_location).with("1.1.1.2").returns(bern)
    UserAuthToken.stubs(:login_location).with("1.1.2.1").returns(london)
  end

  it "will correctly compute distance" do
    def expect_distance(from, to, distance)
      expect(UserAuthToken.distance(from, to).to_i).to eq(distance)
      expect(UserAuthToken.distance(to, from).to_i).to eq(distance)
    end

    expect_distance(zurich, bern, 95)
    expect_distance(zurich, london, 776)
    expect_distance(bern, london, 747)
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
