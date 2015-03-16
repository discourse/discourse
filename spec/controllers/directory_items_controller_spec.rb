require 'spec_helper'

describe DirectoryItemsController do

  it "requires an `id` param" do
    ->{ xhr :get, :index }.should raise_error
  end

  it "requires a proper `id` param" do
    xhr :get, :index, id: 'eviltrout'
    response.should_not be_success
  end

  context "with data" do
    before do
      Fabricate(:user)
      DirectoryItem.refresh!
    end

    it "succeeds with a valid value" do
      xhr :get, :index, id: 'all'
      response.should be_success
      json = ::JSON.parse(response.body)

      json.should be_present
      json['directory_items'].should be_present
      json['total_rows_directory_items'].should be_present
      json['load_more_directory_items'].should be_present
    end
  end
end
