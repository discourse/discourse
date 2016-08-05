require 'rails_helper'

describe DirectoryItemsController do

  it "requires a `period` param" do
    expect{ xhr :get, :index }.to raise_error(ActionController::ParameterMissing)
  end

  it "requires a proper `period` param" do
    xhr :get, :index, period: 'eviltrout'
    expect(response).not_to be_success
  end


  context "without data" do

    context "and a logged in user" do
      let!(:user) { log_in }

      it "succeeds" do
        xhr :get, :index, period: 'all'
        expect(response).to be_success
        json = ::JSON.parse(response.body)
      end
    end

  end


  context "with data" do
    before do
      Fabricate(:user)
      DirectoryItem.refresh!
    end

    it "succeeds with a valid value" do
      xhr :get, :index, period: 'all'
      expect(response).to be_success
      json = ::JSON.parse(response.body)

      expect(json).to be_present
      expect(json['directory_items']).to be_present
      expect(json['total_rows_directory_items']).to be_present
      expect(json['load_more_directory_items']).to be_present
    end

    it "fails when the directory is disabled" do
      SiteSetting.enable_user_directory = false

      xhr :get, :index, period: 'all'
      expect(response).not_to be_success
    end
  end
end
