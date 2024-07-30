# frozen_string_literal: true

describe Chat::MessageRateLimiter do
  fab!(:user) { Fabricate(:user, trust_level: 3) }
  let(:limiter) { described_class.new(user) }

  before do
    freeze_time
    RateLimiter.enable
    SiteSetting.chat_allowed_messages_for_trust_level_0 = 1
    SiteSetting.chat_allowed_messages_for_other_trust_levels = 2
    SiteSetting.chat_auto_silence_duration = 30
  end

  after { limiter.clear! }

  it "does nothing when rate limits are not exceeded" do
    limiter.run!
    expect(user.reload.silenced?).to be false
  end

  it "silences the user for the correct amount of time when they exceed the limit" do
    2.times do
      limiter.run!
      expect(user.reload.silenced?).to be false
    end

    expect { limiter.run! }.to raise_error(RateLimiter::LimitExceeded)

    expect(user.reload.silenced?).to be true
    expect(user.silenced_till).to be_within(0.1).of(30.minutes.from_now)
  end

  it "silences the user correctly based on trust level" do
    user.update(trust_level: 0) # Should only be able to run once without hitting limit
    limiter.run!
    expect(user.reload.silenced?).to be false
    expect { limiter.run! }.to raise_error(RateLimiter::LimitExceeded)
    expect(user.reload.silenced?).to be true
  end

  it "doesn't hit limit if site setting for allowed messages equals 0" do
    SiteSetting.chat_allowed_messages_for_other_trust_levels = 0
    5.times do
      limiter.run!
      expect(user.reload.silenced?).to be false
    end
  end

  it "doesn't silence the user even when the limit is broken if auto_silence_duration is set to 0" do
    SiteSetting.chat_allowed_messages_for_other_trust_levels = 1
    SiteSetting.chat_auto_silence_duration = 0
    limiter.run!
    expect(user.reload.silenced?).to be false

    expect { limiter.run! }.to raise_error(RateLimiter::LimitExceeded)
    expect(user.reload.silenced?).to be false
  end

  it "logs a staff action when the user is silenced" do
    SiteSetting.chat_allowed_messages_for_other_trust_levels = 1
    limiter.run!

    expect { limiter.run! }.to raise_error(RateLimiter::LimitExceeded).and change {
            UserHistory.where(
              target_user: user,
              acting_user: Discourse.system_user,
              action: UserHistory.actions[:silence_user],
            ).count
          }.by(1)
  end
end
