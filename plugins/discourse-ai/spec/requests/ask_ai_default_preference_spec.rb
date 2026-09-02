# frozen_string_literal: true

describe "Ask AI default preference" do
  fab!(:user)

  before do
    enable_current_plugin
    SiteSetting.ai_ask_ai_enabled = true
    sign_in(user)
  end

  it "persists the preference through the user update endpoint" do
    put "/u/#{user.username}.json", params: { ai_ask_ai_default: false }

    expect(response.status).to eq(200)
    expect(user.user_option.reload.ai_ask_ai_default).to eq(false)
  end
end
