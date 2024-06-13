# frozen_string_literal: true

module Jobs
  class EnsureS3UploadsExistence < ::Jobs::Scheduled
    every 1.day

    def perform(*args)
      super
    ensure
      if @db_inventories
        @db_inventories.values.each do |f|
          f.close
          f.unlink
        end
      end
    end

    def prepare_for_all_sites(s3_inventory_bucket)
      inventory = S3Inventory.new(:upload, s3_inventory_bucket:)
      @db_inventories = inventory.prepare_for_all_sites
      @inventory_date = inventory.inventory_date
    end

    def execute(args)
      return if (s3_inventory_bucket = SiteSetting.s3_inventory_bucket).blank?

      if !@db_inventories && Rails.configuration.multisite && GlobalSetting.use_s3?
        prepare_for_all_sites(s3_inventory_bucket)
      end

      if @db_inventories &&
           preloaded_inventory_file =
             @db_inventories[RailsMultisite::ConnectionManagement.current_db]
        S3Inventory.new(
          :upload,
          s3_inventory_bucket:,
          preloaded_inventory_file: preloaded_inventory_file,
          preloaded_inventory_date: @inventory_date,
        ).backfill_etags_and_list_missing
      else
        S3Inventory.new(:upload, s3_inventory_bucket:).backfill_etags_and_list_missing
      end
    end
  end
end
