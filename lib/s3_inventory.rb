require "aws-sdk-s3"
require "csv"
require "discourse_event"

class S3Inventory

  class StorageError < RuntimeError; end

  ::DiscourseEvent.on(:site_setting_saved) do |site_setting|
    name = site_setting.name.to_s
    Jobs.enqueue(:update_s3_inventory) if name.include?("s3_inventory") || name == "s3_upload_bucket"
  end

  attr_reader :inventory_id, :s3_client, :csv_filename,
              :source_bucket_name, :source_bucket_path,
              :destination_bucket_name, :destination_bucket_path

  CSV_ETAG_INDEX ||= 2.freeze

  def initialize(inventory_id = "uploads")
    @source_bucket_name, @source_bucket_path = begin
      raise Discourse::InvalidParameters.new("s3_upload_bucket") if SiteSetting.s3_upload_bucket.blank?
      S3Helper.get_bucket_and_folder_path(SiteSetting.s3_upload_bucket)
    end

    @destination_bucket_name, @destination_bucket_path = begin
      raise Discourse::InvalidParameters.new("s3_inventory_bucket") if SiteSetting.s3_inventory_bucket.blank?
      S3Helper.get_bucket_and_folder_path(SiteSetting.s3_inventory_bucket)
    end

    s3_options = S3Helper.s3_options(SiteSetting)
    @s3_helper = S3Helper.new(SiteSetting.s3_inventory_bucket, '', s3_options)
    @s3_client = @s3_helper.s3_client

    @inventory_id = inventory_id
  end

  def file
    @file ||= unsorted_files.sort_by { |file| -file.last_modified.to_i }.first
  end

  def list_missing_uploads(skip_optimized: false)
    if file.blank?
      Rails.logger.warn("Failed to list inventory from S3")
      raise StorageError
    end

    @current_db = RailsMultisite::ConnectionManagement.current_db
    @timestamp = Time.now.strftime("%Y-%m-%d-%H%M%S")
    @tmp_directory = File.join(Rails.root, "tmp", "inventory", @current_db, @timestamp)
    @archive_filename = File.join(@tmp_directory, File.basename(file.key))
    @csv_filename = @archive_filename[0...-3]
    @logs = []

    FileUtils.mkdir_p(@tmp_directory)
    copy_archive_to_tmp_directory
    unzip_archive

    etags = []
    connection = ActiveRecord::Base.connection.raw_connection
    connection.exec('CREATE TEMP TABLE etags(val text PRIMARY KEY)')

    CSV.foreach(csv_filename, headers: false) do |row|
      next if row[1]["/optimized/"].present? && skip_optimized

      etags << row[S3Inventory::CSV_ETAG_INDEX]

      if etags.length == 1000
        etags_clause = etags.map { |i| "('#{PG::Connection.escape_string(i.to_s)}')" }.join(",")
        connection.exec("INSERT INTO etags VALUES #{etags_clause}")
        etags = []
      end
    end

    if etags.present?
      etags_clause = etags.map { |i| "('#{PG::Connection.escape_string(i.to_s)}')" }.join(",")
      connection.exec("INSERT INTO etags VALUES #{etags_clause}")
    end

    list_missing(Upload)
    list_missing(OptimizedImage) unless skip_optimized
  ensure
    connection.exec('DROP TABLE etags') unless connection.nil?
  end

  def list_missing(model)
    missing_uploads = model.joins('LEFT JOIN etags ON etags.val = etag').where("etags.val is NULL")
    missing_count = missing_uploads.count

    if missing_count > 0
      missing_uploads.find_each do |upload|
        puts upload.url
      end

      puts "#{missing_count} of #{model.count} #{model.name.underscore.pluralize} are missing"
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
    s3_client.put_bucket_policy(
      bucket: destination_bucket_name,
      policy: {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Sid": "InventoryAndAnalyticsPolicy",
            "Effect": "Allow",
            "Principal": { "Service": "s3.amazonaws.com" },
            "Action": ["s3:PutObject"],
            "Resource": ["arn:aws:s3:::#{destination_bucket_name}/*"],
            "Condition": {
              "ArnLike": {
                "aws:SourceArn": "arn:aws:s3:::#{source_bucket_name}"
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
    s3_client.put_bucket_inventory_configuration(
      bucket: source_bucket_name,
      id: inventory_id,
      inventory_configuration: inventory_configuration,
      use_accelerate_endpoint: false
    )
  end

  def inventory_configuration
    config = {
      destination: {
        s3_bucket_destination: {
          bucket: "arn:aws:s3:::#{destination_bucket_name}",
          format: "CSV"
        }
      },
      is_enabled: SiteSetting.enable_s3_inventory,
      id: inventory_id,
      included_object_versions: "Current",
      optional_fields: ["ETag"],
      schedule: {
        frequency: "Daily"
      }
    }
    config[:filter] = { prefix: source_bucket_path } if source_bucket_path.present?
    config[:destination][:s3_bucket_destination][:prefix] = destination_bucket_path if destination_bucket_path.present?
    config
  end

  private

  def unsorted_files
    objects = []

    @s3_helper.list(inventory_data_path).each do |obj|
      if obj.key.match?(/\.csv\.gz$/i)
        objects << obj
      end
    end

    objects
  rescue Aws::Errors::ServiceError => e
    Rails.logger.warn("Failed to list inventory from S3: #{e.message.presence || e.class.name}")
    raise StorageError
  end

  def inventory_data_path
    "#{source_bucket_name}/#{inventory_id}/data"
  end

  def log(message, ex = nil)
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    puts(message)
    publish_log(message, timestamp)
    save_log(message, timestamp)
    Rails.logger.error("#{ex}\n" + ex.backtrace.join("\n")) if ex
  end

  def publish_log(message, timestamp)
    return unless @publish_to_message_bus
    data = { timestamp: timestamp, operation: "restore", message: message }
    MessageBus.publish(BackupRestore::LOGS_CHANNEL, data, user_ids: [@user_id], client_ids: [@client_id])
  end

  def save_log(message, timestamp)
    @logs << "[#{timestamp}] #{message}"
  end

end
