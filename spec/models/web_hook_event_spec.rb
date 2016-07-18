require 'rails_helper'

describe WebHookEvent do
  let(:event) { WebHookEvent.new(status: 200, web_hook: Fabricate(:web_hook)) }
  let(:failed_event) { WebHookEvent.new(status: 400, web_hook: Fabricate(:web_hook)) }

  it 'update last delivery status for associated WebHook record' do
    event.update_web_hook_delivery_status
    expect(event.web_hook.last_delivery_status).to eq(WebHook.last_delivery_statuses[:successful])
  end

  it 'sets last delivery status to failed' do
    failed_event.update_web_hook_delivery_status
    expect(failed_event.web_hook.last_delivery_status).to eq(WebHook.last_delivery_statuses[:failed])
  end
end
