# frozen_string_literal: true

RSpec.describe CurrentUserSerializer do
  fab!(:user)

  let(:serializer) { described_class.new(user, scope: Guardian.new(user), root: false) }

  before do
    SiteSetting.discourse_subscriptions_enabled = true
    SiteSetting.discourse_subscriptions_pricing_table_enabled = true
  end

  it "includes a signed checkout session user reference" do
    user_reference = serializer.discourse_subscriptions_checkout_session_user_reference

    expect(user_reference.length).to be <= 200
    expect(
      User.find_signed(
        user_reference,
        purpose: DiscourseSubscriptions::CHECKOUT_SESSION_USER_REFERENCE_PURPOSE,
      ),
    ).to eq(user)
  end

  it "expires the signed checkout session user reference" do
    user_reference = serializer.discourse_subscriptions_checkout_session_user_reference

    freeze_time(
      (DiscourseSubscriptions::CHECKOUT_SESSION_USER_REFERENCE_EXPIRES_IN + 1.second).from_now,
    ) do
      expect(
        User.find_signed(
          user_reference,
          purpose: DiscourseSubscriptions::CHECKOUT_SESSION_USER_REFERENCE_PURPOSE,
        ),
      ).to be_nil
    end
  end

  it "omits the user reference when pricing tables are disabled" do
    SiteSetting.discourse_subscriptions_pricing_table_enabled = false

    expect(serializer.include_discourse_subscriptions_checkout_session_user_reference?).to eq(false)
  end
end
