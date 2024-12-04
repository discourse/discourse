# frozen_string_literal: true

class S3AssetsHelper
  attr_reader :helper

  def initialize(use_db_s3_config: false)
    @helper = S3Helper.build_from_config(use_db_s3_config:)
  end

  def asset_on_s3?(path)
    existing_assets.include?(prefix_s3_path(path))
  end

  def prefix_s3_path(path)
    path = File.join(helper.s3_bucket_folder_path, path) if helper.s3_bucket_folder_path
    path
  end

  private

  def existing_assets
    return @existing_assets if defined?(@existing_assets)
    @existing_assets = Set.new(@helper.list("assets/").map(&:key))
  end
end
