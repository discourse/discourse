# frozen_string_literal: true

require "rails_helper"

describe SubscriptionMailer do
  fab!(:user) { Fabricate(:user) }

  subject { SubscriptionMailer.confirm_unsubscribe(user) }

  it "contains the right URL" do
    expect(subject.body).to include("#{Discourse.base_url}/email/unsubscribe/#{UnsubscribeKey.last.key}")
  end
end
