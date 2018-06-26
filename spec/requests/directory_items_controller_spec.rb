require 'rails_helper'

describe DirectoryItemsController do
  let!(:user) { Fabricate(:user) }
  let!(:evil_trout) { Fabricate(:evil_trout) }
  let!(:walter_white) { Fabricate(:walter_white) }
  let!(:stage_user) { Fabricate(:staged, username: 'stage_user') }
  let!(:group) { Fabricate(:group, users: [evil_trout, stage_user]) }

  it "requires a `period` param" do
    get '/directory_items.json'
    expect(response.status).to eq(400)
  end

  it "requires a proper `period` param" do
    get '/directory_items.json', params: { period: 'eviltrout' }
    expect(response).not_to be_successful
  end

  context "without data" do

    context "and a logged in user" do
      before { sign_in(user) }

      it "succeeds" do
        get '/directory_items.json', params: { period: 'all' }
        expect(response.status).to eq(200)
      end
    end

  end

  context "with data" do
    before do
      DirectoryItem.refresh!
    end

    it "succeeds with a valid value" do
      get '/directory_items.json', params: { period: 'all' }
      expect(response.status).to eq(200)
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
      expect(response).not_to be_successful
    end

    it "finds user by name" do
      get '/directory_items.json', params: { period: 'all', name: 'eviltrout' }
      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json).to be_present
      expect(json['directory_items'].length).to eq(1)
      expect(json['total_rows_directory_items']).to eq(1)
      expect(json['directory_items'][0]['user']['username']).to eq('eviltrout')
    end

    it "finds staged user by name" do
      get '/directory_items.json', params: { period: 'all', name: 'stage_user' }
      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json).to be_present
      expect(json['directory_items'].length).to eq(1)
      expect(json['total_rows_directory_items']).to eq(1)
      expect(json['directory_items'][0]['user']['username']).to eq('stage_user')
    end

    it "excludes users by username" do
      get '/directory_items.json', params: { period: 'all', exclude_usernames: "stage_user,eviltrout" }
      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json).to be_present
      expect(json['directory_items'].length).to eq(2)
      expect(json['total_rows_directory_items']).to eq(2)
      expect(json['directory_items'][0]['user']['username']).to eq(walter_white.username) | eq(user.username)
      expect(json['directory_items'][1]['user']['username']).to eq(walter_white.username) | eq(user.username)
    end

    it "filters users by group" do
      get '/directory_items.json', params: { period: 'all', group: group.name }
      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json).to be_present
      expect(json['directory_items'].length).to eq(2)
      expect(json['total_rows_directory_items']).to eq(2)
      expect(json['directory_items'][0]['user']['username']).to eq(evil_trout.username) | eq(stage_user.username)
      expect(json['directory_items'][1]['user']['username']).to eq(evil_trout.username) | eq(stage_user.username)
    end
  end
end
