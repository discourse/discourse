require "rails_helper"
require "s3_inventory"
require "file_store/s3_store"

describe "S3Inventory" do
  before do
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_access_key_id = "abc"
    SiteSetting.s3_secret_access_key = "def"
    SiteSetting.s3_inventory_bucket = "ghi"
    SiteSetting.enable_s3_inventory = true

    store = FileStore::S3Store.new
    s3_helper = store.inventory.instance_variable_get(:@s3_helper)
    client = Aws::S3::Client.new(stub_responses: true)
    s3_helper.stubs(:s3_client).returns(client)
    Discourse.stubs(:store).returns(store)
  end

  it "will raise storage error if inventory file not found" do
    expect { Discourse.store.list_missing_uploads }.to raise_error(S3Inventory::StorageError)
  end
end
