# frozen_string_literal: true

require "rails_helper"
require "s3_helper"
require "s3_inventory"
require "file_store/s3_store"

describe "S3Inventory", type: :multisite do
  let(:client) { Aws::S3::Client.new(stub_responses: true) }
  let(:helper) { S3Helper.new(SiteSetting.Upload.s3_upload_bucket.downcase, "", client: client) }
  let(:inventory) { S3Inventory.new(helper, :upload) }
  let(:csv_filename) { "#{Rails.root}/spec/fixtures/csv/s3_inventory.csv" }

  it "can create per-site files" do
    freeze_time
    setup_s3
    SiteSetting.enable_s3_inventory = true
    inventory.stubs(:files).returns([{ key: "Key", filename: "#{csv_filename}.gz" }])
    inventory.stubs(:cleanup!)

    files = inventory.prepare_for_all_sites
    db1 = files["default"].read
    db2 = files["second"].read

    expect(db1.lines.count).to eq(3)
    expect(db2.lines.count).to eq(1)
    files.values.each { |f| f.close; f.unlink }
  end
end
