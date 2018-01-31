require 'rails_helper'

describe DirectoryItemsController do
  let!(:user) { Fabricate(:user) }

  it "requires a `period` param" do
    get '/directory_items.json'
    expect(response.status).to eq(400)
  end

  it "requires a proper `period` param" do
    get '/directory_items.json', params: { period: 'eviltrout' }
    expect(response).not_to be_success
  end

  context "without data" do

    context "and a logged in user" do
      before { sign_in(user) }

      it "succeeds" do
        get '/directory_items.json', params: { period: 'all' }
        expect(response).to be_success
      end
    end

  end

  context "with data" do
    before do
      Fabricate(:evil_trout)
      Fabricate(:walter_white)
      Fabricate(:staged, username: 'stage_user')

      DirectoryItem.refresh!
    end

    it "succeeds with a valid value" do
      get '/directory_items.json', params: { period: 'all' }
      expect(response).to be_success
      json = ::JSON.parse(response.body)

      expect(json).to be_present
      expect(json['directory_items']).to be_present
      expect(json['total_rows_directory_items']).to be_present
      expect(json['load_more_directory_items']).to be_present

      expect(json['directory_items'].length).to eq(4)
      expect(json['total_rows_directory_items']).to eq(4)
    end

    it "fails when the directory is disabled" do
      SiteSetting.enable_user_directory = false

      get '/directory_items.json', params: { period: 'all' }
      expect(response).not_to be_success
    end

    it "finds user by name" do
      get '/directory_items.json', params: { period: 'all', name: 'eviltrout' }
      expect(response).to be_success

      json = ::JSON.parse(response.body)
      expect(json).to be_present
      expect(json['directory_items'].length).to eq(1)
      expect(json['total_rows_directory_items']).to eq(1)
      expect(json['directory_items'][0]['user']['username']).to eq('eviltrout')
    end

    it "finds staged user by name" do
      get '/directory_items.json', params: { period: 'all', name: 'stage_user' }
      expect(response).to be_success

      json = ::JSON.parse(response.body)
      expect(json).to be_present
      expect(json['directory_items'].length).to eq(1)
      expect(json['total_rows_directory_items']).to eq(1)
      expect(json['directory_items'][0]['user']['username']).to eq('stage_user')
    end
  end
end
