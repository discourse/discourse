require "db_helper"
require "digest/sha1"
require "base62"

################################################################################
#                                    gather                                    #
################################################################################

task "uploads:gather" => :environment do
  ENV["RAILS_DB"] ? gather_uploads : gather_uploads_for_all_sites
end

def gather_uploads_for_all_sites
  RailsMultisite::ConnectionManagement.each_connection { gather_uploads }
end

def file_exists?(path)
  File.exists?(path) && File.size(path) > 0
rescue
  false
end

def gather_uploads
  public_directory = "#{Rails.root}/public"
  current_db = RailsMultisite::ConnectionManagement.current_db

  puts "", "Gathering uploads for '#{current_db}'...", ""

  Upload.where("url ~ '^\/uploads\/'")
    .where("url !~ '^\/uploads\/#{current_db}'")
    .find_each do |upload|
    begin
      old_db = upload.url[/^\/uploads\/([^\/]+)\//, 1]
      from = upload.url.dup
      to = upload.url.sub("/uploads/#{old_db}/", "/uploads/#{current_db}/")
      source = "#{public_directory}#{from}"
      destination = "#{public_directory}#{to}"

      # create destination directory & copy file unless it already exists
      unless file_exists?(destination)
        `mkdir -p '#{File.dirname(destination)}'`
        `cp --link '#{source}' '#{destination}'`
      end

      # ensure file has been succesfuly copied over
      raise unless file_exists?(destination)

      # remap links in db
      DbHelper.remap(from, to)
    rescue
      putc "!"
    else
      putc "."
    end
  end

  puts "", "Done!"

end

################################################################################
#                                backfill_shas                                 #
################################################################################

task "uploads:backfill_shas" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Backfilling #{db}..."
    Upload.where(sha1: nil).find_each do |u|
      begin
        path = Discourse.store.path_for(u)
        u.sha1 = Upload.generate_digest(path)
        u.save!
        putc "."
      rescue => e
        puts "Skipping #{u.original_filename} (#{u.url}) #{e.message}"
      end
    end
  end
  puts "", "Done"
end

################################################################################
#                               migrate_from_s3                                #
################################################################################

task "uploads:migrate_from_s3" => :environment do
  ENV["RAILS_DB"] ? migrate_from_s3 : migrate_all_from_s3
end

def guess_filename(url, raw)
  begin
    uri = URI.parse("http:#{url}")
    f = uri.open("rb", read_timeout: 5, redirect: true, allow_redirections: :all)
    filename = if f.meta && f.meta["content-disposition"]
      f.meta["content-disposition"][/filename="([^"]+)"/, 1].presence
    end
    filename ||= raw[/<a class="attachment" href="(?:https?:)?#{Regexp.escape(url)}">([^<]+)<\/a>/, 1].presence
    filename ||= File.basename(url)
    filename
  rescue
    nil
  ensure
    f.try(:close!) rescue nil
  end
end

def migrate_all_from_s3
  RailsMultisite::ConnectionManagement.each_connection { migrate_from_s3 }
end

def migrate_from_s3
  require "file_store/s3_store"

  # make sure S3 is disabled
  if SiteSetting.Upload.enable_s3_uploads
    puts "You must disable S3 uploads before running that task."
    return
  end

  db = RailsMultisite::ConnectionManagement.current_db

  puts "Migrating uploads from S3 to local storage for '#{db}'..."

  max_file_size = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes

  Post
    .where("user_id > 0")
    .where("raw LIKE '%.s3%.amazonaws.com/%' OR raw LIKE '%(upload://%'")
    .find_each do |post|
    begin
      updated = false

      post.raw.gsub!(/(\/\/[\w.-]+amazonaws\.com\/(original|optimized)\/([a-z0-9]+\/)+\h{40}([\w.-]+)?)/i) do |url|
        begin
          if filename = guess_filename(url, post.raw)
            file = FileHelper.download("http:#{url}", max_file_size: max_file_size, tmp_file_name: "from_s3", follow_redirect: true)
            sha1 = Upload.generate_digest(file)
            origin = nil

            existing_upload = Upload.find_by(sha1: sha1)
            if existing_upload&.url&.start_with?("//")
              filename = existing_upload.original_filename
              origin = existing_upload.origin
              existing_upload.destroy
            end

            new_upload = UploadCreator.new(file, filename, origin: origin).create_for(post.user_id || -1)
            if new_upload&.save
              updated = true
              url = new_upload.url
            end
          end

          url
        rescue
          url
        end
      end

      post.raw.gsub!(/(upload:\/\/[0-9a-zA-Z]+\.\w+)/) do |url|
        begin
          if sha1 = Upload.sha1_from_short_url(url)
            if upload = Upload.find_by(sha1: sha1)
              if upload.url.start_with?("//")
                file = FileHelper.download("http:#{upload.url}", max_file_size: max_file_size, tmp_file_name: "from_s3", follow_redirect: true)
                filename = upload.original_filename
                origin = upload.origin
                upload.destroy

                new_upload = UploadCreator.new(file, filename, origin: origin).create_for(post.user_id || -1)
                if new_upload&.save
                  updated = true
                  url = new_upload.url
                end
              end
            end
          end

          url
        rescue
          url
        end
      end

      if updated
        post.save!
        post.rebake!
        putc "#"
      else
        putc "."
      end

    rescue
      putc "X"
    end
  end

  puts "Done!"
end

################################################################################
#                                migrate_to_s3                                 #
################################################################################

task "uploads:migrate_to_s3" => :environment do
  ENV["RAILS_DB"] ? migrate_to_s3 : migrate_to_s3_all_sites
end

def migrate_to_s3_all_sites
  RailsMultisite::ConnectionManagement.each_connection { migrate_to_s3 }
end

def migrate_to_s3
  db = RailsMultisite::ConnectionManagement.current_db

  dry_run = !!ENV["DRY_RUN"]

  puts "*" * 30 + " DRY RUN " + "*" * 30 if dry_run
  puts "Migrating uploads to S3 for '#{db}'..."

  if Upload.where("url NOT LIKE '//%' AND url NOT LIKE '/uploads/#{db}/original/_X/%'").exists?
    puts <<~TEXT
      Some uploads were not migrated to the new scheme. Please run these commands in the rails console

      SiteSetting.migrate_to_new_scheme = true
      Jobs::MigrateUploadScheme.new.execute(nil)
    TEXT
    exit 1
  end

  unless GlobalSetting.use_s3?
    puts <<~TEXT
      Please provide the following environment variables
        - DISCOURSE_S3_BUCKET
        - DISCOURSE_S3_REGION
        - DISCOURSE_S3_ACCESS_KEY_ID
        - DISCOURSE_S3_SECRET_ACCESS_KEY
    TEXT
    exit 2
  end

  if SiteSetting.Upload.s3_cdn_url.blank?
    puts "Please provide the 'DISCOURSE_S3_CDN_URL' environment variable"
    exit 3
  end

  bucket_has_folder_path = true if ENV["DISCOURSE_S3_BUCKET"].include? "/"

  s3 = Aws::S3::Client.new(
    region: ENV["DISCOURSE_S3_REGION"],
    access_key_id: ENV["DISCOURSE_S3_ACCESS_KEY_ID"],
    secret_access_key: ENV["DISCOURSE_S3_SECRET_ACCESS_KEY"])

  if bucket_has_folder_path
    bucket, folder = S3Helper.get_bucket_and_folder_path(ENV["DISCOURSE_S3_BUCKET"])
    folder = File.join(folder, "/")
  else
    bucket, folder = ENV["DISCOURSE_S3_BUCKET"], ""
  end

  begin
    s3.head_bucket(bucket: bucket)
  rescue Aws::S3::Errors::NotFound
    puts "Bucket '#{bucket}' not found. Creating it..."
    s3.create_bucket(bucket: bucket) unless dry_run
  end

  puts "Uploading files to S3..."
  print " - Listing local files"

  local_files = []
  IO.popen("cd public && find uploads/#{db}/original -type f").each do |file|
    local_files << file.chomp
    putc "." if local_files.size % 1000 == 0
  end

  puts " => #{local_files.size} files"
  print " - Listing S3 files"

  s3_objects = []
  prefix = Rails.configuration.multisite ? "#{db}/original/" : "original/"
  options = { bucket: bucket, prefix: folder + prefix }

  loop do
    response = s3.list_objects_v2(options)
    s3_objects.concat(response.contents)
    putc "."
    break if response.next_continuation_token.blank?
    options[:continuation_token] = response.next_continuation_token
  end

  puts " => #{s3_objects.size} files"
  puts " - Syncing files to S3"

  synced = 0
  failed = []

  local_files.each do |file|
    path = File.join("public", file)
    name = File.basename(path)
    etag = Digest::MD5.file(path).hexdigest
    key = file[file.index(prefix)..-1]
    key.prepend(folder) if bucket_has_folder_path

    if s3_object = s3_objects.find { |obj| file.ends_with?(obj.key) }
      next if File.size(path) == s3_object.size && s3_object.etag[etag]
    end

    options = {
      acl: "public-read",
      body: File.open(path, "rb"),
      bucket: bucket,
      content_type: MiniMime.lookup_by_filename(name)&.content_type,
      key: key,
    }

    if !FileHelper.is_supported_image?(name)
      options[:content_disposition] = %Q{attachment; filename="#{name}"}
    end

    if dry_run
      puts "#{file} => #{options[:key]}"
      synced += 1
    elsif s3.put_object(options).etag[etag]
      putc "."
      synced += 1
    else
      putc "X"
      failed << path
    end
  end

  puts

  if failed.size > 0
    puts "Failed to upload #{failed.size} files"
    puts failed.join("\n")
  elsif s3_objects.size + synced >= local_files.size
    puts "Updating the URLs in the database..."

    excluded_tables = %w{
      email_logs
      incoming_emails
      notifications
      post_search_data
      search_logs
      stylesheet_cache
      user_auth_token_logs
      user_auth_tokens
      web_hooks_events
    }

    from = "/uploads/#{db}/original/(\\dX/(?:[a-f0-9]/)*[a-f0-9]{40}[a-z0-9\\.]*)"
    to = "#{SiteSetting.Upload.s3_base_url}/#{prefix}\\1"

    if dry_run
      puts "REPLACING '#{from}' WITH '#{to}'"
    else
      DbHelper.regexp_replace(from, to, excluded_tables: excluded_tables)
    end

    # Uploads that were on base hostname will now be on S3 CDN
    from = "#{Discourse.base_url}#{SiteSetting.Upload.s3_base_url}"
    to = SiteSetting.Upload.s3_cdn_url

    if dry_run
      puts "REMAPPING '#{from}' TO '#{to}'"
    else
      DbHelper.remap(from, to, excluded_tables: excluded_tables)
    end

    if Discourse.asset_host.present?
      # Uploads that were on local CDN will now be on S3 CDN
      from = "#{Discourse.asset_host}#{SiteSetting.Upload.s3_base_url}"
      to = SiteSetting.Upload.s3_cdn_url

      if dry_run
        puts "REMAPPING '#{from}' TO '#{to}'"
      else
        DbHelper.remap(from, to, excluded_tables: excluded_tables)
      end
    end
  end

  puts "Done!"
end

################################################################################
#                                  clean_up                                    #
################################################################################

task "uploads:clean_up" => :environment do
  ENV["RAILS_DB"] ? clean_up_uploads : clean_up_uploads_all_sites
end

def clean_up_uploads_all_sites
  RailsMultisite::ConnectionManagement.each_connection { clean_up_uploads }
end

def clean_up_uploads
  db = RailsMultisite::ConnectionManagement.current_db

  puts "Cleaning up uploads and thumbnails for '#{db}'..."

  if Discourse.store.external?
    puts "This task only works for internal storages."
    exit 1
  end

  puts <<~OUTPUT
  This task will remove upload records and files permanently.

  Would you like to take a full backup before the clean up? (Y/N)
  OUTPUT

  if STDIN.gets.chomp.downcase == 'y'
    puts "Starting backup..."
    backuper = BackupRestore::Backuper.new(Discourse.system_user.id)
    backuper.run
    exit 1 unless backuper.success
  end

  public_directory = Rails.root.join("public").to_s

  ##
  ## DATABASE vs FILE SYSTEM
  ##

  # uploads & avatars
  Upload.find_each do |upload|
    path = File.join(public_directory, upload.url)

    if !File.exists?(path)
      upload.destroy!
      putc "#"
    else
      putc "."
    end
  end

  # optimized images
  OptimizedImage.find_each do |optimized_image|
    path = File.join(public_directory, optimized_image.url)

    if !File.exists?(path)
      optimized_image.destroy!
      putc "#"
    else
      putc "."
    end
  end

  ##
  ## FILE SYSTEM vs DATABASE
  ##

  uploads_directory = File.join(public_directory, 'uploads', db).to_s

  # avatars (no avatar should be stored in that old directory)
  FileUtils.rm_rf("#{uploads_directory}/avatars")

  # uploads and optimized images
  Dir.glob("#{uploads_directory}/**/*.*").each do |file_path|
    sha1 = Upload.generate_digest(file_path)
    url = file_path.split(public_directory, 2)[1]

    if (Upload.where(sha1: sha1).empty? &&
        Upload.where(url: url).empty?) &&
       (OptimizedImage.where(sha1: sha1).empty? &&
        OptimizedImage.where(url: url).empty?)

      FileUtils.rm(file_path)
      putc "#"
    else
      putc "."
    end
  end

  puts "Removing empty directories..."
  puts `find #{uploads_directory} -type d -empty -exec rmdir {} \\;`

  puts "Done!"
end

################################################################################
#                                   missing                                    #
################################################################################

# list all missing uploads and optimized images
task "uploads:missing" => :environment do
  if ENV["RAILS_DB"]
    list_missing_uploads(skip_optimized: ENV['SKIP_OPTIMIZED'])
  else
    RailsMultisite::ConnectionManagement.each_connection do |db|
      list_missing_uploads(skip_optimized: ENV['SKIP_OPTIMIZED'])
    end
  end
end

def list_missing_uploads(skip_optimized: false)
  Discourse.store.list_missing_uploads(skip_optimized: skip_optimized)
end

################################################################################
#                              Recover from tombstone                          #
################################################################################

task "uploads:recover_from_tombstone" => :environment do
  if ENV["RAILS_DB"]
    recover_from_tombstone
  else
    RailsMultisite::ConnectionManagement.each_connection { recover_from_tombstone }
  end
end

def recover_from_tombstone
  if Discourse.store.external?
    puts "This task only works for internal storages."
    return
  end

  begin
    previous_image_size      = SiteSetting.max_image_size_kb
    previous_attachment_size = SiteSetting.max_attachment_size_kb
    previous_extensions      = SiteSetting.authorized_extensions

    SiteSetting.max_image_size_kb      = 10 * 1024
    SiteSetting.max_attachment_size_kb = 10 * 1024
    SiteSetting.authorized_extensions  = "*"

    current_db = RailsMultisite::ConnectionManagement.current_db
    public_path = Rails.root.join("public")
    paths = Dir.glob(File.join(public_path, 'uploads', 'tombstone', current_db, '**', '*.*'))
    max = paths.size

    paths.each_with_index do |path, index|
      filename = File.basename(path)
      printf("%9d / %d (%5.1f%%)\n", (index + 1), max, (((index + 1).to_f / max.to_f) * 100).round(1))

      Post.where("raw LIKE ?", "%#{filename}%").find_each do |post|
        doc = Nokogiri::HTML::fragment(post.raw)
        updated = false

        image_urls = doc.css("img[src]").map { |img| img["src"] }
        attachment_urls = doc.css("a.attachment[href]").map { |a| a["href"] }

        (image_urls + attachment_urls).each do |url|
          next if !url.start_with?("/uploads/")
          next if Upload.exists?(url: url)

          puts "Restoring #{path}..."
          tombstone_path = File.join(public_path, 'uploads', 'tombstone', url.gsub(/^\/uploads\//, ""))

          if File.exists?(tombstone_path)
            File.open(tombstone_path) do |file|
              new_upload = UploadCreator.new(file, File.basename(url)).create_for(Discourse::SYSTEM_USER_ID)

              if new_upload.persisted?
                puts "Restored into #{new_upload.url}"
                DbHelper.remap(url, new_upload.url)
                updated = true
              else
                puts "Failed to create upload for #{url}: #{new_upload.errors.full_messages}."
              end
            end
          else
            puts "Failed to find file (#{tombstone_path}) in tombstone."
          end
        end

        post.rebake! if updated
      end

      sha1 = File.basename(filename, File.extname(filename))
      short_url = "upload://#{Base62.encode(sha1.hex)}"

      Post.where("raw LIKE ?", "%#{short_url}%").find_each do |post|
        puts "Restoring #{path}..."

        File.open(path) do |file|
          new_upload = UploadCreator.new(file, filename).create_for(Discourse::SYSTEM_USER_ID)

          if new_upload.persisted?
            puts "Restored into #{new_upload.short_url}"
            DbHelper.remap(short_url, new_upload.short_url) if short_url != new_upload.short_url
            post.rebake!
          else
            puts "Failed to create upload for #{filename}: #{new_upload.errors.full_messages}."
          end
        end
      end
    end
  ensure
    SiteSetting.max_image_size_kb      = previous_image_size
    SiteSetting.max_attachment_size_kb = previous_attachment_size
    SiteSetting.authorized_extensions  = previous_extensions
  end
end

################################################################################
#                        regenerate_missing_optimized                          #
################################################################################

# regenerate missing optimized images
task "uploads:regenerate_missing_optimized" => :environment do
  if ENV["RAILS_DB"]
    regenerate_missing_optimized
  else
    RailsMultisite::ConnectionManagement.each_connection { regenerate_missing_optimized }
  end
end

def regenerate_missing_optimized
  db = RailsMultisite::ConnectionManagement.current_db

  puts "Regenerating missing optimized images for '#{db}'..."

  if Discourse.store.external?
    puts "This task only works for internal storages."
    return
  end

  public_directory = "#{Rails.root}/public"
  missing_uploads = Set.new

  avatar_upload_ids = UserAvatar.all.pluck(:custom_upload_id, :gravatar_upload_id).flatten.compact

  default_scope = OptimizedImage.includes(:upload)

  [
    default_scope
      .where("optimized_images.upload_id IN (?)", avatar_upload_ids),

    default_scope
      .where("optimized_images.upload_id NOT IN (?)", avatar_upload_ids)
      .where("LENGTH(COALESCE(url, '')) > 0")
      .where("width > 0 AND height > 0")
  ].each do |scope|
    scope.find_each do |optimized_image|
      upload = optimized_image.upload

      next unless optimized_image.url =~ /^\/[^\/]/
      next unless upload.url =~ /^\/[^\/]/

      thumbnail = "#{public_directory}#{optimized_image.url}"
      original = "#{public_directory}#{upload.url}"

      if !File.exists?(thumbnail) || File.size(thumbnail) <= 0
        # make sure the original image exists locally
        if (!File.exists?(original) || File.size(original) <= 0) && upload.origin.present?
          # try to fix it by redownloading it
          begin
            downloaded = FileHelper.download(
              upload.origin,
              max_file_size: SiteSetting.max_image_size_kb.kilobytes,
              tmp_file_name: "discourse-missing",
              follow_redirect: true
            ) rescue nil
            if downloaded && downloaded.size > 0
              FileUtils.mkdir_p(File.dirname(original))
              File.open(original, "wb") { |f| f.write(downloaded.read) }
            end
          ensure
            downloaded.try(:close!) if downloaded.respond_to?(:close!)
          end
        end

        if File.exists?(original) && File.size(original) > 0
          FileUtils.mkdir_p(File.dirname(thumbnail))
          OptimizedImage.resize(original, thumbnail, optimized_image.width, optimized_image.height)
          putc "#"
        else
          missing_uploads << original
          putc "X"
        end
      else
        putc "."
      end
    end
  end

  puts "", "Done"

  if missing_uploads.size > 0
    puts "Missing uploads:"
    missing_uploads.sort.each { |u| puts u }
  end
end

################################################################################
#                             migrate_to_new_scheme                            #
################################################################################

task "uploads:start_migration" => :environment do
  SiteSetting.migrate_to_new_scheme = true
  puts "Migration started!"
end

task "uploads:stop_migration" => :environment do
  SiteSetting.migrate_to_new_scheme = false
  puts "Migration stoped!"
end

task "uploads:analyze", [:cache_path, :limit] => :environment do |_, args|
  now = Time.zone.now
  current_db = RailsMultisite::ConnectionManagement.current_db

  puts "Analyzing uploads for '#{current_db}'... This may take awhile...\n"
  cache_path = args[:cache_path]

  current_db = RailsMultisite::ConnectionManagement.current_db
  uploads_path = Rails.root.join('public', 'uploads', current_db)

  path =
    if cache_path
      cache_path
    else
      path = "/tmp/#{current_db}-#{now.to_i}-paths.txt"
      FileUtils.touch("/tmp/#{now.to_i}-paths.txt")
      `find #{uploads_path} -type f -printf '%s %h/%f\n' > #{path}`
      path
    end

  extensions = {}
  paths_count = 0

  File.readlines(path).each do |line|
    size, file_path = line.split(" ", 2)

    paths_count += 1
    extension = File.extname(file_path).chomp.downcase
    extensions[extension] ||= {}
    extensions[extension]["count"] ||= 0
    extensions[extension]["count"] += 1
    extensions[extension]["size"] ||= 0
    extensions[extension]["size"] += size.to_i
  end

  uploads_count = Upload.count
  optimized_images_count = OptimizedImage.count

  puts <<~REPORT
  Report for '#{current_db}'
  -----------#{'-' * current_db.length}
  Number of `Upload` records in DB: #{uploads_count}
  Number of `OptimizedImage` records in DB: #{optimized_images_count}
  **Total DB records: #{uploads_count + optimized_images_count}**

  Number of images in uploads folder: #{paths_count}
  ------------------------------------#{'-' * paths_count.to_s.length}

  REPORT

  helper = Class.new do
    include ActionView::Helpers::NumberHelper
  end

  helper = helper.new

  printf "%-15s | %-15s | %-15s\n", 'extname', 'total size', 'count'
  puts "-" * 45

  extensions.sort_by { |_, value| value['size'] }.reverse.each do |extname, value|
    printf "%-15s | %-15s | %-15s\n", extname, helper.number_to_human_size(value['size']), value['count']
  end

  puts "\n"

  limit = args[:limit] || 10

  sql = <<~SQL
    SELECT
      users.username,
      COUNT(uploads.user_id) AS num_of_uploads,
      SUM(uploads.filesize) AS total_size_of_uploads,
      COUNT(optimized_images.id) AS num_of_optimized_images
    FROM users
    INNER JOIN uploads ON users.id = uploads.user_id
    INNER JOIN optimized_images ON uploads.id = optimized_images.upload_id
    GROUP BY users.id
    ORDER BY total_size_of_uploads DESC
    LIMIT #{limit}
  SQL

  puts "Users using the most disk space"
  puts "-------------------------------\n"
  printf "%-25s | %-25s | %-25s | %-25s\n", 'username', 'total size of uploads', 'number of uploads', 'number of optimized images'
  puts "-" * 110

  DB.query_single(sql).each do |username, num_of_uploads, total_size_of_uploads, num_of_optimized_images|
    printf "%-25s | %-25s | %-25s | %-25s\n", username, helper.number_to_human_size(total_size_of_uploads), num_of_uploads, num_of_optimized_images
  end

  puts "\n"
  puts "List of file paths @ #{path}"
  puts "Duration: #{Time.zone.now - now} seconds"
end

task "uploads:fix_incorrect_extensions" => :environment do
  require_dependency "upload_fixer"
  UploadFixer.fix_all_extensions
end

task "uploads:recover" => :environment do
  require_dependency "upload_recovery"

  dry_run = ENV["DRY_RUN"].present?

  if ENV["RAILS_DB"]
    UploadRecovery.new(dry_run: dry_run).recover
  else
    RailsMultisite::ConnectionManagement.each_connection do |db|
      UploadRecovery.new(dry_run: dry_run).recover
    end
  end
end
