# frozen_string_literal: true

require "s3_helper"
require "s3_inventory"
require "file_store/s3_store"

RSpec.describe "S3Inventory", type: :multisite do
  let(:inventory) do
    S3Inventory.new(:upload, s3_inventory_bucket: "some-inventory-bucket/some/prefix")
  end

  let(:csv_filename) { "#{Rails.root}/spec/fixtures/csv/s3_inventory.csv" }

  it "can create per-site files" do
    freeze_time
    setup_s3

    inventory.stubs(:files).returns([{ key: "Key", filename: "#{csv_filename}.gz" }])
    inventory.stubs(:cleanup!)

    files = inventory.prepare_for_all_sites
    db1 = files["default"].read
    db2 = files["second"].read

    expect(db1.lines.count).to eq(4)
    expect(db2.lines.count).to eq(1)

    files.values.each do |f|
      f.close
      f.unlink
    end
  end
end
