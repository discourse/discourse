require 'spec_helper'

describe DirectoryItemsController do

  it "requires a `period` param" do
    ->{ xhr :get, :index }.should raise_error
  end

  it "requires a proper `period` param" do
    xhr :get, :index, period: 'eviltrout'
    response.should_not be_success
  end


  context "without data" do

    context "and a logged in user" do
      let!(:user) { log_in }

      it "succeeds" do
        xhr :get, :index, period: 'all'
        response.should be_success
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
      response.should be_success
      json = ::JSON.parse(response.body)

      json.should be_present
      json['directory_items'].should be_present
      json['total_rows_directory_items'].should be_present
      json['load_more_directory_items'].should be_present
    end

    it "fails when the directory is disabled" do
      SiteSetting.enable_user_directory = false

      xhr :get, :index, period: 'all'
      response.should_not be_success
    end
  end
end
