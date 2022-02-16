# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe Jobs::DiscourseAutomationCallZapierWebhook do
  before do
    SiteSetting.discourse_automation_enabled = true
    freeze_time
    Jobs::run_immediately!

    stub_request(:post, 'https://foo.com/').
      with(
        body: 'null',
        headers: {
          'Host' => 'foo.com'
        }
      ).to_return(status: 200, body: '', headers: {})
  end

  it 'is rate limited' do
    RateLimiter.enable

    expect do
      6.times do
        Jobs.enqueue(:discourse_automation_call_zapier_webhook, webhook_url: 'https://foo.com')
      end
    end.to raise_error(RateLimiter::LimitExceeded)
  end
end
