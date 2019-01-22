require "aws-sdk-s3"
require "csv"
require "discourse_event"

class S3Inventory

  class StorageError < RuntimeError; end

  ::DiscourseEvent.on(:site_setting_saved) do |site_setting|
    name = site_setting.name.to_s
    Jobs.enqueue(:update_s3_inventory) if name.include?("s3_inventory") || name == "s3_upload_bucket"
  end

  attr_reader :inventory_id, :csv_filename, :model

  CSV_KEY_INDEX ||= 1.freeze
  CSV_ETAG_INDEX ||= 2.freeze
  INVENTORY_PREFIX ||= "inventory".freeze

  def initialize(s3_helper, type)
    @s3_helper = s3_helper

    if type == :upload
      @inventory_id = "uploads"
      @model = Upload
    elsif type == :optimized
      @inventory_id = "optimized"
      @model = OptimizedImage
    end
  end

  def file
    @file ||= unsorted_files.sort_by { |file| -file.last_modified.to_i }.first
  end

  def list_missing
    if file.blank?
      Rails.logger.warn("Failed to list inventory from S3")
      raise StorageError
    end

    DistributedMutex.synchronize("s3_inventory_list_missing_#{inventory_id}") do
      current_db = RailsMultisite::ConnectionManagement.current_db
      timestamp = Time.now.strftime("%Y-%m-%d-%H%M%S")
      @tmp_directory = File.join(Rails.root, "tmp", INVENTORY_PREFIX, current_db, timestamp)
      @archive_filename = File.join(@tmp_directory, File.basename(file.key))
      @csv_filename = @archive_filename[0...-3]

      FileUtils.mkdir_p(@tmp_directory)
      copy_archive_to_tmp_directory
      unzip_archive

      begin
        table_name = "#{inventory_id}_inventory"
        connection = ActiveRecord::Base.connection.raw_connection
        connection.exec("CREATE TEMP TABLE #{table_name}(key text UNIQUE, etag text PRIMARY KEY)")
        connection.copy_data("COPY #{table_name} FROM STDIN CSV") do
          CSV.foreach(csv_filename, headers: false) do |row|
            connection.put_copy_data("#{row[CSV_KEY_INDEX]},#{row[CSV_ETAG_INDEX]}\n")
          end
        end

        missing_uploads = model.joins("LEFT JOIN #{table_name} ON #{table_name}.etag = #{model.table_name}.etag").where("#{table_name}.etag is NULL")
        missing_count = missing_uploads.count

        if missing_count > 0
          missing_uploads.find_each do |upload|
            puts upload.url
          end

          puts "#{missing_count} of #{model.count} #{model.name.underscore.pluralize} are missing"
        end
      ensure
        connection.exec("DROP TABLE #{table_name}") unless connection.nil?
      end
    end
  end

  def copy_archive_to_tmp_directory
    log "Downloading archive to tmp directory..."
    failure_message = "Failed to download archive to tmp directory."

    @s3_helper.download_file(file.key, @archive_filename, failure_message)
  end

  def unzip_archive
    log "Unzipping archive, this may take a while..."

    FileUtils.cd(@tmp_directory) do
      Discourse::Utils.execute_command('gzip', '--decompress', @archive_filename, failure_message: "Failed to unzip archive.")
    end
  end

  def update_bucket_policy
    @s3_helper.s3_client.put_bucket_policy(
      bucket: bucket_name,
      policy: {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid": "InventoryAndAnalyticsPolicy",
            "Effect": "Allow",
            "Principal": { "Service": "s3.amazonaws.com" },
            "Action": ["s3:PutObject"],
            "Resource": ["arn:aws:s3:::#{inventory_path}/*"],
            "Condition": {
              "ArnLike": {
                "aws:SourceArn": "arn:aws:s3:::#{bucket_name}"
              },
              "StringEquals": {
                "s3:x-amz-acl": "bucket-owner-full-control"
              }
            }
          }
        ]
      }.to_json
    )
  end

  def update_bucket_inventory_configuration
    @s3_helper.s3_client.put_bucket_inventory_configuration(
      bucket: bucket_name,
      id: inventory_id,
      inventory_configuration: inventory_configuration,
      use_accelerate_endpoint: false
    )
  end

  def inventory_configuration
    filter_prefix = inventory_id
    destination_prefix = File.join(INVENTORY_PREFIX, inventory_id)

    if bucket_folder_path.present?
      filter_prefix = File.join(bucket_folder_path, filter_prefix)
      destination_prefix = File.join(bucket_folder_path, destination_prefix)
    end

    {
      destination: {
        s3_bucket_destination: {
          bucket: "arn:aws:s3:::#{bucket_name}",
          prefix: destination_prefix,
          format: "CSV"
        }
      },
      filter: {
        prefix: filter_prefix
      },
      is_enabled: SiteSetting.enable_s3_inventory,
      id: inventory_id,
      included_object_versions: "Current",
      optional_fields: ["ETag"],
      schedule: {
        frequency: "Daily"
      }
    }
  end

  private

  def bucket_name
    @s3_helper.s3_bucket_name
  end

  def bucket_folder_path
    @s3_helper.s3_bucket_folder_path
  end

  def unsorted_files
    objects = []

    @s3_helper.list(File.join(inventory_path, "data")).each do |obj|
      if obj.key.match?(/\.csv\.gz$/i)
        objects << obj
      end
    end

    objects
  rescue Aws::Errors::ServiceError => e
    Rails.logger.warn("Failed to list inventory from S3: #{e.message.presence || e.class.name}")
    raise StorageError
  end

  def inventory_path
    File.join(bucket_name, bucket_folder_path || "", INVENTORY_PREFIX, inventory_id)
  end

  def log(message, ex = nil)
    puts(message)
    Rails.logger.error("#{ex}\n" + ex.backtrace.join("\n")) if ex
  end
end
