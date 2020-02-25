# frozen_string_literal: true

require "s3_inventory"

module Jobs
  # if upload bucket changes or inventory bucket changes we want to update s3 bucket policy and inventory configuration
  class UpdateS3Inventory < ::Jobs::Base

    def execute(args)
      return unless SiteSetting.enable_s3_inventory? &&
        SiteSetting.Upload.enable_s3_uploads &&
        SiteSetting.s3_configure_inventory_policy

      [:upload, :optimized].each do |type|
        s3_inventory = S3Inventory.new(Discourse.store.s3_helper, type)
        s3_inventory.update_bucket_policy if type == :upload
        s3_inventory.update_bucket_inventory_configuration
      end
    end
  end
end
