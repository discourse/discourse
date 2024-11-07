# frozen_string_literal: true

require "aws-sdk-s3"
require "csv"

class S3Inventory
  attr_reader :type, :inventory_date, :s3_helper

  CSV_KEY_INDEX = 1
  CSV_ETAG_INDEX = 2
  INVENTORY_PREFIX = "inventory"
  INVENTORY_LAG = 2.days
  WAIT_AFTER_RESTORE_DAYS = 2

  def initialize(
    type,
    s3_inventory_bucket:,
    preloaded_inventory_file: nil,
    preloaded_inventory_date: nil,
    s3_options: {}
  )
    @s3_helper = S3Helper.new(s3_inventory_bucket, "", s3_options)

    if preloaded_inventory_file && preloaded_inventory_date
      # Data preloaded, so we don't need to fetch it again
      @preloaded_inventory_file = preloaded_inventory_file
      @inventory_date = preloaded_inventory_date
    end

    if type == :upload
      @type = "original"
      @model = Upload
      @scope = @model.by_users.without_s3_file_missing_confirmed_verification_status
    elsif type == :optimized
      @type = "optimized"
      @scope = @model = OptimizedImage
    else
      raise "Invalid type: #{type}"
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
            connection.exec(
              "CREATE TEMP TABLE #{tmp_table_name}(url text UNIQUE, etag text, PRIMARY KEY(etag, url))",
            )

            connection.copy_data("COPY #{tmp_table_name} FROM STDIN CSV") do
              for_each_inventory_row do |row|
                key = row[CSV_KEY_INDEX]

                next if Rails.configuration.multisite && key.exclude?(multisite_prefix)
                next if key.exclude?("#{type}/")

                url = File.join(Discourse.store.absolute_base_url, key)
                connection.put_copy_data("#{url},#{row[CSV_ETAG_INDEX]}\n")
              end
            end

            table_name = @model.table_name

            # backfilling etags
            connection.async_exec(
              "UPDATE #{table_name}
              SET etag = #{tmp_table_name}.etag
              FROM #{tmp_table_name}
              WHERE #{table_name}.etag IS NULL AND
                #{table_name}.url = #{tmp_table_name}.url",
            )

            uploads = @scope.where("updated_at < ?", inventory_date)

            missing_uploads =
              uploads.joins(
                "LEFT JOIN #{tmp_table_name} ON #{tmp_table_name}.etag = #{table_name}.etag",
              ).where(
                "#{tmp_table_name}.etag IS NULL OR #{tmp_table_name}.url != #{table_name}.url",
              )

            exists_with_different_etag =
              missing_uploads
                .joins(
                  "LEFT JOIN #{tmp_table_name} inventory2 ON inventory2.url = #{table_name}.url",
                )
                .where("inventory2.etag IS NOT NULL")
                .pluck(:id)

            exists_with_different_url =
              missing_uploads
                .joins(
                  "LEFT JOIN #{tmp_table_name} inventory3 ON inventory3.etag = #{table_name}.etag",
                )
                .where("inventory3.url != #{table_name}.url")
                .pluck(:id)

            # marking as verified/not verified
            if @model == Upload
              sql_params = {
                inventory_date: inventory_date,
                invalid_etag: Upload.verification_statuses[:invalid_etag],
                invalid_url: Upload.verification_statuses[:invalid_url],
                s3_file_missing_confirmed: Upload.verification_statuses[:s3_file_missing_confirmed],
                verified: Upload.verification_statuses[:verified],
                seeded_id_threshold: @model::SEEDED_ID_THRESHOLD,
              }

              DB.exec(<<~SQL, sql_params)
                UPDATE #{table_name}
                SET verification_status = :verified
                WHERE etag IS NOT NULL
                  AND verification_status <> :verified
                  AND verification_status <> :s3_file_missing_confirmed
                  AND updated_at < :inventory_date
                  AND id > :seeded_id_threshold
                  AND EXISTS
                    (
                        SELECT 1
                        FROM #{tmp_table_name}
                        WHERE #{tmp_table_name}.etag = #{table_name}.etag
                    )
              SQL

              DB.exec(<<~SQL, sql_params)
                UPDATE #{table_name}
                SET verification_status = :invalid_etag
                WHERE verification_status <> :invalid_etag
                  AND verification_status <> :s3_file_missing_confirmed
                  AND updated_at < :inventory_date
                  AND id > :seeded_id_threshold
                  AND NOT EXISTS
                    (
                        SELECT 1
                        FROM #{tmp_table_name}
                        WHERE #{tmp_table_name}.etag = #{table_name}.etag
                    )
              SQL

              DB.exec(<<~SQL, sql_params)
                UPDATE #{table_name}
                SET verification_status = :invalid_url
                WHERE verification_status <> :invalid_url
                  AND verification_status <> :invalid_etag
                  AND verification_status <> :s3_file_missing_confirmed
                  AND updated_at < :inventory_date
                  AND id > :seeded_id_threshold
                  AND NOT EXISTS
                    (
                        SELECT 1
                        FROM #{tmp_table_name}
                        WHERE #{tmp_table_name}.url = #{table_name}.url
                    )
              SQL
            end

            if (missing_count = missing_uploads.count) > 0
              missing_uploads
                .select(:id, :url)
                .find_each do |upload|
                  if exists_with_different_etag.include?(upload.id)
                    log "#{upload.url} has different etag"
                  elsif exists_with_different_url.include?(upload.id)
                    log "#{upload.url} has different url"
                  else
                    log upload.url
                  end
                end

              log "#{missing_count} of #{uploads.count} #{@scope.name.underscore.pluralize} are missing"
              if exists_with_different_etag.present?
                log "#{exists_with_different_etag.count} of these are caused by differing etags"
                log "Null the etag column and re-run for automatic backfill"
              end
              if exists_with_different_url.present?
                log "#{exists_with_different_url.count} of these are caused by differing urls"
                log "Empty the url column and re-run for automatic backfill"
              end
            end

            set_missing_s3_discourse_stats(missing_count)
          ensure
            connection.exec("DROP TABLE #{tmp_table_name}") unless connection.nil?
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
      files.each { |file| CSV.foreach(file[:filename][0...-3]) { |row| yield(row) } }
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
    Discourse::Utils.execute_command(
      "gzip",
      "--decompress",
      file[:filename],
      failure_message: "Failed to decompress inventory file '#{file[:filename]}'.",
      chdir: tmp_directory,
    )
  end

  def prepare_for_all_sites
    db_names = RailsMultisite::ConnectionManagement.all_dbs
    db_files = {}

    db_names.each { |db| db_files[db] = Tempfile.new("#{db}-inventory.csv") }

    download_and_decompress_files
    for_each_inventory_row do |row|
      key = row[CSV_KEY_INDEX]
      row_db = key.match(%r{uploads/([^/]+)/})&.[](1)
      if row_db && file = db_files[row_db]
        file.write(row.to_csv)
      end
    end

    db_names.each { |db| db_files[db].rewind }

    db_files
  ensure
    cleanup!
  end

  def s3_client
    @s3_helper.s3_client
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

  def tmp_table_name
    "#{type}_inventory"
  end

  def files
    return if @preloaded_inventory_file

    @files ||=
      begin
        symlink_file = unsorted_files.sort_by { |file| -file.last_modified.to_i }.first

        return [] if symlink_file.blank?

        if BackupMetadata.last_restore_date.present? &&
             (symlink_file.last_modified - WAIT_AFTER_RESTORE_DAYS.days) <
               BackupMetadata.last_restore_date
          set_missing_s3_discourse_stats(0)
          return []
        end

        @inventory_date = symlink_file.last_modified - INVENTORY_LAG
        log "Downloading symlink file to tmp directory..."
        failure_message = "Failed to download symlink file to tmp directory."
        filename = File.join(tmp_directory, File.basename(symlink_file.key))

        @s3_helper.download_file(symlink_file.key, filename, failure_message)

        return [] if !File.exist?(filename)

        File
          .readlines(filename)
          .map do |key|
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
    @tmp_directory ||=
      begin
        current_db = RailsMultisite::ConnectionManagement.current_db
        directory = File.join(Rails.root, "tmp", INVENTORY_PREFIX, current_db)
        FileUtils.mkdir_p(directory)
        directory
      end
  end

  def bucket_name
    @s3_helper.s3_bucket_name
  end

  def bucket_folder_path
    @s3_helper.s3_bucket_folder_path
  end

  def unsorted_files
    objects = []
    hive_path = File.join(bucket_folder_path, "hive")
    @s3_helper.list(hive_path).each { |obj| objects << obj if obj.key.match?(/symlink\.txt\z/i) }

    objects
  rescue Aws::Errors::ServiceError => e
    log("Failed to list inventory from S3", e)
    []
  end

  def log(message, ex = nil)
    puts(message)
    Rails.logger.error("#{ex}\n" + (ex.backtrace || []).join("\n")) if ex
  end

  def error(message)
    log(message, StandardError.new(message))
  end

  def set_missing_s3_discourse_stats(count)
    Discourse.stats.set("missing_s3_#{@model.table_name}", count)
  end
end
