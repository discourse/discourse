# frozen_string_literal: true

RSpec.describe Jobs::EnsureS3UploadsExistence do
  subject(:job) { described_class.new }

  context "when `s3_inventory_bucket` has been set" do
    before { SiteSetting.s3_inventory_bucket = "some-bucket-name" }

    it "works" do
      S3Inventory.any_instance.expects(:backfill_etags_and_list_missing).once
      job.execute({})
    end
  end

  context "when `s3_inventory_bucket` has not been set" do
    before { SiteSetting.s3_inventory_bucket = nil }

    it "doesn't execute" do
      S3Inventory.any_instance.expects(:backfill_etags_and_list_missing).never
      job.execute({})
    end
  end
end
