# frozen_string_literal: true

require "aws-sdk-s3"
require "csv"

class S3Inventory

  attr_reader :type, :model, :inventory_date

  CSV_KEY_INDEX ||= 1
  CSV_ETAG_INDEX ||= 2
  INVENTORY_PREFIX ||= "inventory"
  INVENTORY_VERSION ||= "1"
  INVENTORY_LAG ||= 2.days

  def initialize(s3_helper, type, preloaded_inventory_file: nil, preloaded_inventory_date: nil)
    @s3_helper = s3_helper

    if preloaded_inventory_file && preloaded_inventory_date
      # Data preloaded, so we don't need to fetch it again
      @preloaded_inventory_file = preloaded_inventory_file
      @inventory_date = preloaded_inventory_date
    end

    if type == :upload
      @type = "original"
      @model = Upload
    elsif type == :optimized
      @type = "optimized"
      @model = OptimizedImage
    end
  end

  def backfill_etags_and_list_missing
    if !@preloaded_inventory_file && files.blank?
      error("Failed to list inventory from S3")
      return
    end

    DistributedMutex.synchronize("s3_inventory_list_missing_#{type}", validity: 30.minutes) do
      begin
        download_and_decompress_files if !@preloaded_inventory_file

        multisite_prefix = Discourse.store.upload_path
        ActiveRecord::Base.transaction do
          begin
            connection.exec("CREATE TEMP TABLE #{table_name}(url text UNIQUE, etag text, PRIMARY KEY(etag, url))")
            connection.copy_data("COPY #{table_name} FROM STDIN CSV") do
              for_each_inventory_row do |row|
                key = row[CSV_KEY_INDEX]
                next if Rails.configuration.multisite && key.exclude?(multisite_prefix)
                url = File.join(Discourse.store.absolute_base_url, key)
                connection.put_copy_data("#{url},#{row[CSV_ETAG_INDEX]}\n")
              end
            end

            # backfilling etags
            connection.async_exec("UPDATE #{model.table_name}
              SET etag = #{table_name}.etag
              FROM #{table_name}
              WHERE #{model.table_name}.etag IS NULL AND
                #{model.table_name}.url = #{table_name}.url")

            uploads = model.where("updated_at < ?", inventory_date)
            uploads = uploads.by_users if model == Upload

            missing_uploads = uploads
              .joins("LEFT JOIN #{table_name} ON #{table_name}.etag = #{model.table_name}.etag")
              .where("#{table_name}.etag IS NULL")

            exists_with_different_etag = missing_uploads
              .joins("LEFT JOIN #{table_name} inventory2 ON inventory2.url = #{model.table_name}.url")
              .where("inventory2.etag IS NOT NULL").pluck(:id)

            # marking as verified/not verified
            if model == Upload
              sql_params = {
                inventory_date: inventory_date,
                unchecked: Upload.verification_statuses[:unchecked],
                invalid_etag: Upload.verification_statuses[:invalid_etag],
                verified: Upload.verification_statuses[:verified]
              }
              DB.exec(<<~SQL, sql_params)
                UPDATE #{model.table_name}
                SET verification_status = CASE WHEN table_name_alias.etag IS NULL
                  THEN :invalid_etag
                  ELSE :verified
                END
                FROM #{model.table_name} AS model_table
                LEFT JOIN #{table_name} AS table_name_alias ON
                  model_table.etag = table_name_alias.etag
                WHERE model_table.id = #{model.table_name}.id
                AND model_table.updated_at < :inventory_date
                AND (
                  model_table.verification_status = :unchecked OR
                  model_table.verification_status <> CASE WHEN table_name_alias.etag IS NULL
                    THEN :invalid_etag
                    ELSE :verified
                  END
                )
                AND model_table.id > #{model::SEEDED_ID_THRESHOLD}
              SQL
            end

            if (missing_count = missing_uploads.count) > 0
              missing_uploads.select(:id, :url).find_each do |upload|
                if exists_with_different_etag.include?(upload.id)
                  log "#{upload.url} has different etag"
                else
                  log upload.url
                end
              end

              log "#{missing_count} of #{uploads.count} #{model.name.underscore.pluralize} are missing"
              if exists_with_different_etag.present?
                log "#{exists_with_different_etag.count} of these are caused by differing etags"
                log "Null the etag column and re-run for automatic backfill"
              end
            end

            Discourse.stats.set("missing_s3_#{model.table_name}", missing_count)
          ensure
            connection.exec("DROP TABLE #{table_name}") unless connection.nil?
          end
        end
      ensure
        cleanup!
      end
    end
  end

  def for_each_inventory_row
    if @preloaded_inventory_file
      CSV.foreach(@preloaded_inventory_file) { |row| yield(row) }
    else
      files.each do |file|
        CSV.foreach(file[:filename][0...-3]) { |row| yield(row) }
      end
    end
  end

  def download_inventory_file_to_tmp_directory(file)
    return if File.exist?(file[:filename])

    log "Downloading inventory file '#{file[:key]}' to tmp directory..."
    failure_message = "Failed to inventory file '#{file[:key]}' to tmp directory."

    @s3_helper.download_file(file[:key], file[:filename], failure_message)
  end

  def decompress_inventory_file(file)
    log "Decompressing inventory file '#{file[:filename]}', this may take a while..."
    Discourse::Utils.execute_command('gzip', '--decompress', file[:filename], failure_message: "Failed to decompress inventory file '#{file[:filename]}'.", chdir: tmp_directory)
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
            "Resource": ["#{inventory_path_arn}/*"],
            "Condition": {
              "ArnLike": {
                "aws:SourceArn": bucket_arn
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

  def prepare_for_all_sites
    db_names = RailsMultisite::ConnectionManagement.all_dbs
    db_files = {}

    db_names.each do |db|
      db_files[db] = Tempfile.new("#{db}-inventory.csv")
    end

    download_and_decompress_files
    for_each_inventory_row do |row|
      key = row[CSV_KEY_INDEX]
      row_db = key.match(/uploads\/([^\/]+)\//)&.[](1)
      if row_db && file = db_files[row_db]
        file.write(row.to_csv)
      end
    end

    db_names.each do |db|
      db_files[db].rewind
    end

    db_files
  ensure
    cleanup!
  end

  private

  def cleanup!
    return if @preloaded_inventory_file
    files.each do |file|
      File.delete(file[:filename]) if File.exist?(file[:filename])
      File.delete(file[:filename][0...-3]) if File.exist?(file[:filename][0...-3])
    end
  end

  def connection
    @connection ||= ActiveRecord::Base.connection.raw_connection
  end

  def table_name
    "#{type}_inventory"
  end

  def files
    return if @preloaded_inventory_file
    @files ||= begin
      symlink_file = unsorted_files.sort_by { |file| -file.last_modified.to_i }.first
      return [] if symlink_file.blank?

      @inventory_date = symlink_file.last_modified - INVENTORY_LAG
      log "Downloading symlink file to tmp directory..."
      failure_message = "Failed to download symlink file to tmp directory."
      filename = File.join(tmp_directory, File.basename(symlink_file.key))

      @s3_helper.download_file(symlink_file.key, filename, failure_message)
      File.readlines(filename).map do |key|
        key = key.sub("s3://#{bucket_name}/", "").sub("\n", "")
        { key: key, filename: File.join(tmp_directory, File.basename(key)) }
      end
    end
  end

  def download_and_decompress_files
    files.each do |file|
      next if File.exist?(file[:filename][0...-3])

      download_inventory_file_to_tmp_directory(file)
      decompress_inventory_file(file)
    end
  end

  def tmp_directory
    @tmp_directory ||= begin
      current_db = RailsMultisite::ConnectionManagement.current_db
      directory = File.join(Rails.root, "tmp", INVENTORY_PREFIX, current_db)
      FileUtils.mkdir_p(directory)
      directory
    end
  end

  def inventory_configuration
    filter_prefix = type
    filter_prefix = bucket_folder_path if bucket_folder_path.present?

    {
      destination: {
        s3_bucket_destination: {
          bucket: bucket_arn,
          prefix: inventory_path,
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

  def bucket_name
    @s3_helper.s3_bucket_name
  end

  def bucket_folder_path
    @s3_helper.s3_bucket_folder_path
  end

  def unsorted_files
    objects = []

    hive_path = File.join(inventory_path, bucket_name, inventory_id, "hive")
    @s3_helper.list(hive_path).each do |obj|
      if obj.key.match?(/symlink\.txt$/i)
        objects << obj
      end
    end

    objects
  rescue Aws::Errors::ServiceError => e
    log("Failed to list inventory from S3", e)
    []
  end

  def inventory_id
    @inventory_id ||= begin
      id = Rails.configuration.multisite ? "original" : type  # TODO: rename multisite path to "uploads"
      bucket_folder_path.present? ? "#{bucket_folder_path}-#{id}" : id
    end
  end

  def inventory_path_arn
    File.join(bucket_arn, inventory_path)
  end

  def inventory_path
    path = File.join(INVENTORY_PREFIX, INVENTORY_VERSION)
    path = File.join(bucket_folder_path, path) if bucket_folder_path.present?
    path
  end

  def bucket_arn
    "arn:aws:s3:::#{bucket_name}"
  end

  def log(message, ex = nil)
    puts(message)
    Rails.logger.error("#{ex}\n" + (ex.backtrace || []).join("\n")) if ex
  end

  def error(message)
    log(message, StandardError.new(message))
  end
end
