# frozen_string_literal: true

RSpec.describe SubscriptionMailer do
  subject(:mail) { SubscriptionMailer.confirm_unsubscribe(user) }

  fab!(:user)

  it "contains the right URL" do
    expect(mail.body).to include(
      "#{Discourse.base_url}/email/unsubscribe/#{UnsubscribeKey.last.key}",
    )
  end
end
