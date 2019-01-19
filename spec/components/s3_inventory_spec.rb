require "rails_helper"
require "s3_inventory"
require "file_store/s3_store"

describe "S3Inventory" do
  let(:store) { FileStore::S3Store.new }
  let(:inventory) { store.inventory }
  let(:csv_filename) { File.new("#{Rails.root}/spec/fixtures/csv/s3_inventory.csv") }

  before do
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_access_key_id = "abc"
    SiteSetting.s3_secret_access_key = "def"
    SiteSetting.enable_s3_inventory = true

    s3_helper = store.inventory.instance_variable_get(:@s3_helper)
    client = Aws::S3::Client.new(stub_responses: true)
    client.stub_responses(:list_objects, {
      contents: [
        {
          etag: "\"70ee1738b6b21e2c8a43f3a5ab0eee71\"", 
          key: "example1.csv.gz", 
          last_modified: Time.parse("2014-11-21T19:40:05.000Z"), 
          owner: {
            display_name: "myname", 
            id: "12345example25102679df27bb0ae12b3f85be6f290b936c4393484be31bebcc", 
          }, 
          size: 11, 
          storage_class: "STANDARD",
        }, 
        {
          etag: "\"9c8af9a76df052144598c115ef33e511\"", 
          key: "example2.csv.gz", 
          last_modified: Time.parse("2013-11-15T01:10:49.000Z"), 
          owner: {
            display_name: "myname", 
            id: "12345example25102679df27bb0ae12b3f85be6f290b936c4393484be31bebcc", 
          }, 
          size: 713193, 
          storage_class: "STANDARD", 
        }
      ],
      next_marker: "eyJNYXJrZXIiOiBudWxsLCAiYm90b190cnVuY2F0ZV9hbW91bnQiOiAyfQ=="
    })
    s3_helper.stubs(:s3_client).returns(client)
    Discourse.stubs(:store).returns(store)
  end

  it "will return recent inventory file name" do
    expect(inventory.file.key).to eq("example1.csv.gz")
  end

  it "will raise storage error if inventory file not found" do
    inventory.stubs(:file).returns(nil)
    expect { inventory.list_missing_uploads }.to raise_error(S3Inventory::StorageError)
  end

  it "will raise storage error if inventory file not found" do
    CSV.foreach(csv_filename, headers: false) do |row|
      Fabricate(:upload, etag: row[S3Inventory::CSV_ETAG_INDEX])
    end

    upload = Fabricate(:upload, etag: "ETag")
    inventory.stubs(:unzip_archive)
    inventory.stubs(:log)
    inventory.stubs(:csv_filename).returns(csv_filename)
    STDOUT.expects(:puts).with(upload.url)
    STDOUT.expects(:puts).with("1 of 4 uploads are missing")
    inventory.list_missing_uploads
  end
end
