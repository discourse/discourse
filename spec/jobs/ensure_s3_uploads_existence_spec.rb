# frozen_string_literal: true

RSpec.describe Jobs::EnsureS3UploadsExistence do
  subject(:job) { described_class.new }

  context "with S3 inventory enabled" do
    before do
      setup_s3
      SiteSetting.enable_s3_inventory = true
    end

    it "works" do
      S3Inventory.any_instance.expects(:backfill_etags_and_list_missing).once
      job.execute({})
    end
  end

  context "with S3 inventory disabled" do
    before { SiteSetting.enable_s3_inventory = false }

    it "doesn't execute" do
      S3Inventory.any_instance.expects(:backfill_etags_and_list_missing).never
      job.execute({})
    end
  end
end
