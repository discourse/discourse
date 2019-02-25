require 'rails_helper'

describe EdgerydersMultisite::ActionsController do
  before do
    SiteSetting.queue_jobs = false
  end

  it 'can list' do
    sign_in(Fabricate(:user))
    get "/edgeryders-multisite/list.json"
    expect(response.status).to eq(200)
  end
end
