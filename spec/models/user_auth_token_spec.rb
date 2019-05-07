# frozen_string_literal: true

require 'rails_helper'
require 'discourse_ip_info'

describe UserAuthToken do

  it "can remove old expired tokens" do

    SiteSetting.verbose_auth_token_logging = true

    freeze_time Time.zone.now
    SiteSetting.maximum_session_age = 1

    user = Fabricate(:user)
    token = UserAuthToken.generate!(user_id: user.id,
                                    user_agent: "some user agent 2",
                                    client_ip: "1.1.2.3")

    freeze_time 1.hour.from_now
    UserAuthToken.cleanup!

    expect(UserAuthToken.where(id: token.id).count).to eq(1)

    freeze_time 1.second.from_now
    UserAuthToken.cleanup!

    expect(UserAuthToken.where(id: token.id).count).to eq(1)

    freeze_time UserAuthToken::ROTATE_TIME.from_now
    UserAuthToken.cleanup!

    expect(UserAuthToken.where(id: token.id).count).to eq(0)

  end

  it "can lookup hashed" do
    user = Fabricate(:user)

    token = UserAuthToken.generate!(user_id: user.id,
                                    user_agent: "some user agent 2",
                                    client_ip: "1.1.2.3")

    lookup_token = UserAuthToken.lookup(token.unhashed_auth_token)

    expect(user.id).to eq(lookup_token.user.id)

    lookup_token = UserAuthToken.lookup(token.auth_token)

    expect(lookup_token).to eq(nil)
  end

  it "can validate token was seen at lookup time" do

    user = Fabricate(:user)

    user_token = UserAuthToken.generate!(user_id: user.id,
                                         user_agent: "some user agent 2",
                                         client_ip: "1.1.2.3")

    expect(user_token.auth_token_seen).to eq(false)

    UserAuthToken.lookup(user_token.unhashed_auth_token, seen: true)

    user_token.reload
    expect(user_token.auth_token_seen).to eq(true)

  end

  it "can rotate with no params maintaining data" do

    user = Fabricate(:user)

    user_token = UserAuthToken.generate!(user_id: user.id,
                                         user_agent: "some user agent 2",
                                         client_ip: "1.1.2.3")

    user_token.update_columns(auth_token_seen: true)
    expect(user_token.rotate!).to eq(true)
    user_token.reload
    expect(user_token.client_ip.to_s).to eq("1.1.2.3")
    expect(user_token.user_agent).to eq("some user agent 2")
  end

  it "expires correctly" do

    user = Fabricate(:user)

    user_token = UserAuthToken.generate!(user_id: user.id,
                                         user_agent: "some user agent 2",
                                         client_ip: "1.1.2.3")

    UserAuthToken.lookup(user_token.unhashed_auth_token, seen: true)

    freeze_time (SiteSetting.maximum_session_age.hours - 1).from_now

    user_token.reload

    user_token.rotate!
    UserAuthToken.lookup(user_token.unhashed_auth_token, seen: true)

    freeze_time (SiteSetting.maximum_session_age.hours - 1).from_now

    still_good = UserAuthToken.lookup(user_token.unhashed_auth_token, seen: true)
    expect(still_good).not_to eq(nil)

    freeze_time 2.hours.from_now

    not_good = UserAuthToken.lookup(user_token.unhashed_auth_token, seen: true)
    expect(not_good).to eq(nil)
  end

  it "can properly rotate tokens" do

    user = Fabricate(:user)

    user_token = UserAuthToken.generate!(user_id: user.id,
                                         user_agent: "some user agent 2",
                                         client_ip: "1.1.2.3")

    prev_auth_token = user_token.auth_token
    unhashed_prev = user_token.unhashed_auth_token

    rotated = user_token.rotate!(user_agent: "a new user agent", client_ip: "1.1.2.4")
    expect(rotated).to eq(false)

    user_token.update_columns(auth_token_seen: true)

    rotated = user_token.rotate!(user_agent: "a new user agent", client_ip: "1.1.2.4")
    expect(rotated).to eq(true)

    user_token.reload

    expect(user_token.rotated_at).to be_within(5.second).of(Time.zone.now)
    expect(user_token.client_ip).to eq("1.1.2.4")
    expect(user_token.user_agent).to eq("a new user agent")
    expect(user_token.auth_token_seen).to eq(false)
    expect(user_token.seen_at).to eq(nil)
    expect(user_token.prev_auth_token).to eq(prev_auth_token)

    # ability to auth using an old token
    freeze_time

    looked_up = UserAuthToken.lookup(user_token.unhashed_auth_token, seen: true)
    expect(looked_up.id).to eq(user_token.id)
    expect(looked_up.auth_token_seen).to eq(true)
    expect(looked_up.seen_at).to be_within(1.second).of(Time.zone.now)

    looked_up = UserAuthToken.lookup(unhashed_prev, seen: true)
    expect(looked_up.id).to eq(user_token.id)

    freeze_time(2.minute.from_now)

    looked_up = UserAuthToken.lookup(unhashed_prev)
    expect(looked_up).not_to eq(nil)

    looked_up.reload
    expect(looked_up.auth_token_seen).to eq(false)

    rotated = user_token.rotate!(user_agent: "a new user agent", client_ip: "1.1.2.4")
    expect(rotated).to eq(true)
    user_token.reload
    expect(user_token.seen_at).to eq(nil)
  end

  it "keeps prev token valid for 1 minute after it is confirmed" do

    user = Fabricate(:user)

    token = UserAuthToken.generate!(user_id: user.id,
                                    user_agent: "some user agent",
                                    client_ip: "1.1.2.3")

    UserAuthToken.lookup(token.unhashed_auth_token, seen: true)

    freeze_time(10.minutes.from_now)

    prev_token = token.unhashed_auth_token

    token.rotate!(user_agent: "firefox", client_ip: "1.1.1.1")

    freeze_time(10.minutes.from_now)

    expect(UserAuthToken.lookup(token.unhashed_auth_token, seen: true)).not_to eq(nil)
    expect(UserAuthToken.lookup(prev_token, seen: true)).not_to eq(nil)

  end

  it "can correctly log auth tokens" do
    SiteSetting.verbose_auth_token_logging = true

    user = Fabricate(:user)

    token = UserAuthToken.generate!(user_id: user.id,
                                    user_agent: "some user agent",
                                    client_ip: "1.1.2.3")

    expect(UserAuthTokenLog.where(
      action: 'generate',
      user_id: user.id,
      user_agent: "some user agent",
      client_ip: "1.1.2.3",
      user_auth_token_id: token.id,
    ).count).to eq(1)

    UserAuthToken.lookup(token.unhashed_auth_token,
      seen: true,
      user_agent: "something diff",
      client_ip: "1.2.3.3"
    )

    UserAuthToken.lookup(token.unhashed_auth_token,
      seen: true,
      user_agent: "something diff2",
      client_ip: "1.2.3.3"
    )

    expect(UserAuthTokenLog.where(
      action: "seen token",
      user_id: user.id,
      auth_token: token.auth_token,
      client_ip: "1.2.3.3",
      user_auth_token_id: token.id
    ).count).to eq(1)

    fake_token = SecureRandom.hex
    UserAuthToken.lookup(fake_token,
                         seen: true,
                         user_agent: "bob",
                         client_ip: "127.0.0.1",
                         path: "/path"
                        )

    expect(UserAuthTokenLog.where(
      action: "miss token",
      auth_token: UserAuthToken.hash_token(fake_token),
      user_agent: "bob",
      client_ip: "127.0.0.1",
      path: "/path"
    ).count).to eq(1)

    freeze_time(UserAuthToken::ROTATE_TIME.from_now)

    token.rotate!(user_agent: "firefox", client_ip: "1.1.1.1")

    expect(UserAuthTokenLog.where(
      action: "rotate",
      auth_token: token.auth_token,
      user_agent: "firefox",
      client_ip: "1.1.1.1",
      user_auth_token_id: token.id
    ).count).to eq(1)

  end

  it "calls before_destroy" do
    SiteSetting.verbose_auth_token_logging = true

    user = Fabricate(:user)

    token = UserAuthToken.generate!(user_id: user.id,
                                    user_agent: "some user agent",
                                    client_ip: "1.1.2.3")

    expect(user.user_auth_token_logs.count).to eq(1)

    token.destroy

    expect(user.user_auth_token_logs.count).to eq(2)
    expect(user.user_auth_token_logs.last.action).to eq("destroy")
    expect(user.user_auth_token_logs.last.user_agent).to eq("some user agent")
    expect(user.user_auth_token_logs.last.client_ip).to eq("1.1.2.3")
  end

  it "will not mark token unseen when prev and current are the same" do
    user = Fabricate(:user)

    token = UserAuthToken.generate!(user_id: user.id,
                                    user_agent: "some user agent",
                                    client_ip: "1.1.2.3")

    lookup = UserAuthToken.lookup(token.unhashed_auth_token, seen: true)
    lookup = UserAuthToken.lookup(token.unhashed_auth_token, seen: true)
    lookup.reload
    expect(lookup.auth_token_seen).to eq(true)
  end

  context "suspicious login" do

    fab!(:user) { Fabricate(:user) }
    fab!(:admin) { Fabricate(:admin) }

    it "is not checked when generated for non-staff" do
      UserAuthToken.generate!(user_id: user.id, staff: user.staff?)

      expect(Jobs::SuspiciousLogin.jobs.size).to eq(0)
    end

    it "is checked when generated for staff" do
      UserAuthToken.generate!(user_id: admin.id, staff: admin.staff?)

      expect(Jobs::SuspiciousLogin.jobs.size).to eq(1)
    end

    it "is not checked when generated by impersonate" do
      UserAuthToken.generate!(user_id: admin.id, staff: admin.staff?, impersonate: true)

      expect(Jobs::SuspiciousLogin.jobs.size).to eq(0)
    end

  end

end
