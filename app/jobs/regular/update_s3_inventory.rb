module Jobs
  # if upload bucket changes or inventory bucket changes we want to update s3 bucket policy and inventory configuration
  class UpdateS3Inventory < Jobs::Base

    def execute(args)
      return unless SiteSetting.enable_s3_inventory? && SiteSetting.enable_s3_uploads?

      s3_inventory = Discourse.store.s3_inventory
      s3_inventory.update_bucket_policy
      s3_inventory.update_bucket_inventory_configuration
    end
  end
end
