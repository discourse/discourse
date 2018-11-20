require 'rails_helper'

describe Admin::ScreenedEmailsController do
  it "is a subclass of AdminController" do
    expect(Admin::ScreenedEmailsController < Admin::AdminController).to eq(true)
  end

  describe '#index' do
    before do
      sign_in(Fabricate(:admin))
    end

    it 'returns JSON' do
      Fabricate(:screened_email)
      get "/admin/logs/screened_emails.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json.size).to eq(1)
    end
  end
end
