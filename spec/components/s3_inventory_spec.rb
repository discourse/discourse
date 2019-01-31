require "rails_helper"
require "s3_inventory"
require "file_store/s3_store"

describe "S3Inventory" do
  let(:client) { Aws::S3::Client.new(stub_responses: true) }
  let(:store) { Discourse.store }
  let(:inventory) { S3Inventory.new(store.s3_helper, :upload) }
  let(:csv_filename) { "#{Rails.root}/spec/fixtures/csv/s3_inventory.csv" }

  before do
    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_access_key_id = "abc"
    SiteSetting.s3_secret_access_key = "def"
    SiteSetting.enable_s3_inventory = true

    client.stub_responses(:list_objects,
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
    )
    store.s3_helper.stubs(:s3_client).returns(client)
  end

  it "should return the latest inventory file name" do
    expect(inventory.file.key).to eq("example1.csv.gz")
  end

  it "should raise error if an inventory file is not found" do
    client.stub_responses(:list_objects, contents: [])
    output = capture_stdout { inventory.list_missing }
    expect(output).to eq("Failed to list inventory from S3\n")
  end

  it "should display missing uploads correctly" do
    CSV.foreach(csv_filename, headers: false) do |row|
      Fabricate(:upload, etag: row[S3Inventory::CSV_ETAG_INDEX])
    end

    upload = Fabricate(:upload, etag: "ETag")
    inventory.expects(:decompress_inventory_file)
    inventory.expects(:csv_filename).returns(csv_filename)

    output = capture_stdout do
      inventory.list_missing
    end

    expect(output).to eq("Downloading inventory file to tmp directory...\n#{upload.url}\n1 of 4 uploads are missing\n")
  end
end
