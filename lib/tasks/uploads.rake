# frozen_string_literal: true

require "db_helper"
require "digest/sha1"
require "base62"

################################################################################
#                                    gather                                    #
################################################################################

require_dependency "rake_helpers"

task "uploads:gather" => :environment do
  ENV["RAILS_DB"] ? gather_uploads : gather_uploads_for_all_sites
end

def gather_uploads_for_all_sites
  RailsMultisite::ConnectionManagement.each_connection { gather_uploads }
end

def file_exists?(path)
  File.exist?(path) && File.size(path) > 0
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

      # ensure file has been successfully copied over
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
        sha1 = Upload.generate_digest(path)
        u.sha1 = u.secure? ? SecureRandom.hex(20) : sha1
        u.original_sha1 = u.secure? ? sha1 : nil
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
#                                migrate_to_s3                                 #
################################################################################

task "uploads:migrate_to_s3" => :environment do
  STDOUT.puts("Please note that migrating to S3 is currently not reversible! \n[CTRL+c] to cancel, [ENTER] to continue")
  STDIN.gets

  ENV["RAILS_DB"] ? migrate_to_s3 : migrate_to_s3_all_sites
end

def migrate_to_s3_all_sites
  RailsMultisite::ConnectionManagement.each_connection do
    begin
      migrate_to_s3
    rescue RuntimeError => e
      if ENV["SKIP_FAILED"]
        puts e
      else
        raise e unless ENV["SKIP_FAILED"]
      end
    end
  end
end

def create_migration
  FileStore::ToS3Migration.new(
    s3_options: FileStore::ToS3Migration.s3_options_from_env,
    dry_run: !!ENV["DRY_RUN"],
    migrate_to_multisite: !!ENV["MIGRATE_TO_MULTISITE"],
    skip_etag_verify: !!ENV["SKIP_ETAG_VERIFY"]
  )
end

def migrate_to_s3
  create_migration.migrate
end

task "uploads:s3_migration_status" => :environment do
  success = true
  RailsMultisite::ConnectionManagement.each_connection do
    success &&= create_migration.migration_successful?
  end

  queued_jobs = Sidekiq::Stats.new.queues.sum { |_ , x| x }
  if queued_jobs > 50
    puts "WARNING: There are #{queued_jobs} jobs queued! Wait till Sidekiq clears backlog prior to migrating site to a new host"
    exit 1
  end

  if !success
    puts "Site is not ready for migration"
    exit 1
  end

  puts "All sites appear to have uploads in order!"
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

    if !File.exist?(path)
      upload.destroy!
      putc "#"
    else
      putc "."
    end
  end

  # optimized images
  OptimizedImage.find_each do |optimized_image|
    path = File.join(public_directory, optimized_image.url)

    if !File.exist?(path)
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
#                                missing files                                 #
################################################################################

# list all missing uploads and optimized images
task "uploads:missing_files" => :environment do
  if ENV["RAILS_DB"]
    list_missing_uploads(skip_optimized: ENV['SKIP_OPTIMIZED'])
  else
    RailsMultisite::ConnectionManagement.each_connection do |db|
      if ENV["SKIP_EXTERNAL"] == "1" && Discourse.store.external?
        puts "#{RailsMultisite::ConnectionManagement.current_db} has uploads stored externally skipping!"
      else
        if Discourse.store.external?
          puts "-" * 80
          puts "WARNING! WARNING! WARNING!"
          puts "-" * 80
          puts
          puts <<~TEXT
            #{RailsMultisite::ConnectionManagement.current_db} has uploads on S3!
            validating without inventory is likely to take an enormous amount of time.
            We recommend you run SKIP_EXTERNAL=1 rake uploads:missing to skip validating if on a multisite.
          TEXT
        end
        list_missing_uploads(skip_optimized: ENV['SKIP_OPTIMIZED'])
      end
    end
  end
end

def list_missing_uploads(skip_optimized: false)
  Discourse.store.list_missing_uploads(skip_optimized: skip_optimized)
end

task "uploads:missing" => :environment do
  Rake::Task["uploads:missing_files"].invoke
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

      if !File.exist?(thumbnail) || File.size(thumbnail) <= 0
        # make sure the original image exists locally
        if (!File.exist?(original) || File.size(original) <= 0) && upload.origin.present?
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

        if File.exist?(original) && File.size(original) > 0
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
  UploadFixer.fix_all_extensions
end

task "uploads:recover_from_tombstone" => :environment do
  Rake::Task["uploads:recover"].invoke
end

task "uploads:recover" => :environment do

  dry_run = ENV["DRY_RUN"].present?
  stop_on_error = ENV["STOP_ON_ERROR"].present?

  if ENV["RAILS_DB"]
    UploadRecovery.new(dry_run: dry_run, stop_on_error: stop_on_error).recover
  else
    RailsMultisite::ConnectionManagement.each_connection do |db|
      UploadRecovery.new(dry_run: dry_run, stop_on_error: stop_on_error).recover
    end
  end
end

task "uploads:sync_s3_acls" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    unless Discourse.store.external?
      puts "This task only works for external storage."
      exit 1
    end

    puts "CAUTION: This task may take a long time to complete!"
    puts "-" * 30
    puts "Uploads marked as secure will get a private ACL, and uploads marked as not secure will get a public ACL."
    adjust_acls(Upload.find_each(batch_size: 100))
    puts "", "Upload ACL sync complete!"
  end
end

task "uploads:disable_secure_media" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    unless Discourse.store.external?
      puts "This task only works for external storage."
      exit 1
    end

    puts "Disabling secure media and resetting uploads to not secure in #{db}...", ""

    SiteSetting.secure_media = false

    secure_uploads = Upload.includes(:posts).where(secure: true)
    secure_upload_count = secure_uploads.count
    uploads_to_adjust_acl_for = []
    posts_to_rebake = {}

    i = 0
    secure_uploads.find_each(batch_size: 20).each do |upload|
      uploads_to_adjust_acl_for << upload

      upload.posts.each do |post|
        # don't want unnecessary double-ups
        next if posts_to_rebake.key?(post.id)
        posts_to_rebake[post.id] = post
      end

      i += 1
    end

    puts "", "Marking #{secure_upload_count} uploads as not secure.", ""
    secure_uploads.update_all(secure: false)

    adjust_acls(uploads_to_adjust_acl_for)
    post_rebake_errors = rebake_upload_posts(posts_to_rebake)
    log_rebake_errors(post_rebake_errors)

    RakeHelpers.print_status_with_label("Rebaking and updating complete!            ", i, secure_upload_count)
  end

  puts "", "Secure media is now disabled!", ""
end

# Renamed to uploads:secure_upload_analyse_and_update
task "uploads:ensure_correct_acl" => :environment do
  puts "This task has been deprecated, run uploads:secure_upload_analyse_and_update task instead."
  exit 1
end

##
# Run this task whenever the secure_media or login_required
# settings are changed for a Discourse instance to update
# the upload secure flag and S3 upload ACLs. Any uploads that
# have their secure status changed will have all associated posts
# rebaked.
task "uploads:secure_upload_analyse_and_update" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    unless Discourse.store.external?
      puts "This task only works for external storage."
      exit 1
    end

    puts "Analyzing security for uploads in #{db}...", ""
    upload_ids_to_mark_as_secure, upload_ids_to_mark_as_not_secure, posts_to_rebake, uploads_to_adjust_acl_for = nil
    Upload.transaction do
      mark_secure_in_loop_because_no_login_required = false

      # If secure media is enabled we need to first set the access control post of
      # all post uploads (even uploads that are linked to multiple posts). If the
      # upload is not set to secure media then this has no other effect on the upload,
      # but we _must_ know what the access control post is because the with_secure_media?
      # method is on the post, and this knows about the category security & PM status
      if SiteSetting.secure_media?
        update_uploads_access_control_post
      end

      # Get all uploads in the database, including optimized images. Both media (images, videos,
      # etc) along with attachments (pdfs, txt, etc.) must be loaded because all can be marked as
      # secure based on site settings.
      uploads_to_update = Upload.includes(:posts, :optimized_images).joins(:post_uploads)

      puts "There are #{uploads_to_update.count} upload(s) that could be marked secure.", ""

      # Simply mark all these uploads as secure if login_required because no anons will be able to access them
      if SiteSetting.login_required?
        mark_secure_in_loop_because_no_login_required = false
      else

        # If NOT login_required, then we have to go for the other slower flow, where in the loop
        # we mark the upload secure based on UploadSecurity.should_be_secure?
        mark_secure_in_loop_because_no_login_required = true
        puts "Marking posts as secure in the next step because login_required is false."
      end

      puts "", "Analysing which of #{uploads_to_update.count} uploads need to be marked secure and be rebaked.", ""

      upload_ids_to_mark_as_secure,
        upload_ids_to_mark_as_not_secure,
        posts_to_rebake,
        uploads_to_adjust_acl_for = determine_upload_security_and_posts_to_rebake(
        uploads_to_update, mark_secure_in_loop_because_no_login_required
      )

      if !SiteSetting.login_required?
        update_specific_upload_security_no_login_required(upload_ids_to_mark_as_secure, upload_ids_to_mark_as_not_secure)
      else
        mark_all_as_secure_login_required(uploads_to_update)
      end
    end

    # Enqueue rebakes AFTER upload transaction complete, so there is no race condition
    # between updating the DB and the rebakes occurring.
    post_rebake_errors = rebake_upload_posts(posts_to_rebake)
    log_rebake_errors(post_rebake_errors)

    # Also do this AFTER upload transaction complete so we don't end up with any
    # errors leaving ACLs in a bad state (the ACL sync task can be run to fix any
    # outliers at any time).
    adjust_acls(uploads_to_adjust_acl_for)
  end
  puts "", "", "Done!"
end

def adjust_acls(uploads_to_adjust_acl_for)
  total_count = uploads_to_adjust_acl_for.respond_to?(:length) ? uploads_to_adjust_acl_for.length : uploads_to_adjust_acl_for.count
  puts "", "Updating ACL for #{total_count} uploads.", ""
  i = 0
  uploads_to_adjust_acl_for.each do |upload|
    RakeHelpers.print_status_with_label("Updating ACL for upload.......", i, total_count)
    Discourse.store.update_upload_ACL(upload)
    i += 1
  end
  RakeHelpers.print_status_with_label("Updating ACLs complete!        ", i, total_count)
end

def mark_all_as_secure_login_required(uploads_to_update)
  puts "Marking #{uploads_to_update.count} upload(s) as secure because login_required is true.", ""
  uploads_to_update.update_all(
    secure: true,
    security_last_changed_at: Time.zone.now,
    security_last_changed_reason: "upload security rake task all secure login required"
  )
  puts "Finished marking upload(s) as secure."
end

def log_rebake_errors(rebake_errors)
  return if rebake_errors.empty?
  puts "The following post rebakes failed with error:", ""
  rebake_errors.each do |message|
    puts message
  end
end

def update_specific_upload_security_no_login_required(upload_ids_to_mark_as_secure, upload_ids_to_mark_as_not_secure)
  if upload_ids_to_mark_as_secure.any?
    puts "Marking #{upload_ids_to_mark_as_secure.length} uploads as secure because UploadSecurity determined them to be secure."
    Upload.where(id: upload_ids_to_mark_as_secure).update_all(
      secure: true,
      security_last_changed_at: Time.zone.now,
      security_last_changed_reason: "upload security rake task mark as secure"
    )
  end
  if upload_ids_to_mark_as_not_secure.any?
    puts "Marking #{upload_ids_to_mark_as_not_secure.length} uploads as not secure because UploadSecurity determined them to be not secure."
    Upload.where(id: upload_ids_to_mark_as_not_secure).update_all(
      secure: false,
      security_last_changed_at: Time.zone.now,
      security_last_changed_reason: "upload security rake task mark as not secure"
    )
  end
  puts "Finished updating upload security."
end

def update_uploads_access_control_post
  access_control_post_updates = []
  uploads_with_post_ids = DB.query(<<-SQL
    SELECT upload_id, (
      SELECT string_agg(CAST(post_uploads.post_id AS varchar), ',' ORDER BY post_uploads.id) as post_ids
      FROM post_uploads
      WHERE pu.upload_id = post_uploads.upload_id
    ) FROM post_uploads pu
  SQL
  )
  uploads_with_post_ids.each do |row|
    first_post_id = row.post_ids.split(",").first.to_i
    access_control_post_updates << "UPDATE uploads SET access_control_post_id = #{first_post_id} WHERE id = #{row.upload_id};"
  end
  DB.exec(access_control_post_updates.join("\n"))
end

def rebake_upload_posts(posts_to_rebake)
  posts_to_rebake = posts_to_rebake.values
  post_rebake_errors = []
  puts "", "Rebaking #{posts_to_rebake.length} posts with affected uploads.", ""
  begin
    i = 0
    posts_to_rebake.each do |post|
      RakeHelpers.print_status_with_label("Rebaking posts.....", i, posts_to_rebake.length)
      post.rebake!
      i += 1
    end

    RakeHelpers.print_status_with_label("Rebaking complete!            ", i, posts_to_rebake.length)
    puts ""
  rescue => e
    post_rebake_errors << e.message
  end
  post_rebake_errors
end

def determine_upload_security_and_posts_to_rebake(uploads_to_update, mark_secure_in_loop_because_no_login_required)
  upload_ids_to_mark_as_secure = []
  upload_ids_to_mark_as_not_secure = []
  uploads_to_adjust_acl_for = []
  posts_to_rebake = {}

  # we do this to avoid a heavier post query, and to make sure we only
  # get unique posts AND include deleted posts (unscoped)
  unique_access_control_posts = {}
  Post.unscoped.select(:id, :topic_id)
    .includes(topic: :category)
    .where(id: uploads_to_update.pluck(:access_control_post_id).uniq).find_each do |post|
    unique_access_control_posts[post.id] = post
  end

  i = 0
  uploads_to_update.find_each do |upload_to_update|

    # fetch the post out of the already populated map to avoid n1s
    upload_to_update.access_control_post = unique_access_control_posts[upload_to_update.access_control_post_id]

    # we just need to determine the post security here so the ACL is set to the correct thing,
    # because the update_upload_ACL method uses upload.secure?
    original_update_secure_status = upload_to_update.secure
    upload_to_update.secure = UploadSecurity.new(upload_to_update).should_be_secure?

    # no point changing ACLs or rebaking or doing any such shenanigans
    # when the secure status hasn't even changed!
    if original_update_secure_status == upload_to_update.secure
      i += 1
      next
    end

    # we only want to update the acl later once the secure status
    # has been saved in the DB; otherwise if there is a later failure
    # we get stuck with an incorrect ACL in S3
    uploads_to_adjust_acl_for << upload_to_update
    RakeHelpers.print_status_with_label("Analysing which upload posts to rebake.....", i, uploads_to_update.count)
    upload_to_update.posts.each do |post|
      # don't want unnecessary double-ups
      next if posts_to_rebake.key?(post.id)
      posts_to_rebake[post.id] = post
    end

    # some uploads will be marked as not secure here.
    # we need to address this with upload_ids_to_mark_as_not_secure
    # e.g. turning off SiteSetting.login_required
    if mark_secure_in_loop_because_no_login_required
      if upload_to_update.secure?
        upload_ids_to_mark_as_secure << upload_to_update.id
      else
        upload_ids_to_mark_as_not_secure << upload_to_update.id
      end
    end

    i += 1
  end
  RakeHelpers.print_status_with_label("Analysis complete!            ", i, uploads_to_update.count)
  puts ""

  [upload_ids_to_mark_as_secure, upload_ids_to_mark_as_not_secure, posts_to_rebake, uploads_to_adjust_acl_for]
end

def inline_uploads(post)
  replaced = false

  original_raw = post.raw

  post.raw = post.raw.gsub(/(\((\/uploads\S+).*\))/) do
    upload = Upload.find_by(url: $2)
    if !upload
      data = Upload.extract_url($2)
      if data && sha1 = data[2]
        upload = Upload.find_by(sha1: sha1)
        if !upload
          sha_map = JSON.parse(post.custom_fields["UPLOAD_SHA1_MAP"] || "{}")
          if mapped_sha = sha_map[sha1]
            upload = Upload.find_by(sha1: mapped_sha)
          end
        end
      end
    end
    result = $1

    if upload&.id
      result.sub!($2, upload.short_url)
      replaced = true
    else
      puts "Upload not found #{$2} in Post #{post.id} - #{post.url}"
    end
    result
  end

  if replaced
    puts "Corrected image urls in #{post.full_url} raw backup stored in custom field"
    post.custom_fields["BACKUP_POST_RAW"] = original_raw
    post.save_custom_fields
    post.save!(validate: false)
    post.rebake!
  end
end

def inline_img_tags(post)
  replaced = false

  original_raw = post.raw
  post.raw = post.raw.gsub(/(<img\s+src=["'](\/uploads\/[^'"]*)["'].*>)/i) do
    next if $2.include?("..")

    upload = Upload.find_by(url: $2)
    if !upload
      data = Upload.extract_url($2)
      if data && sha1 = data[2]
        upload = Upload.find_by(sha1: sha1)
      end
    end
    if !upload
      local_file = File.join(Rails.root, "public", $2)
      if File.exist?(local_file)
        File.open(local_file) do |f|
          upload = UploadCreator.new(f, "image").create_for(post.user_id)
        end
      end
    end

    if upload
      replaced = true
      "![image](#{upload.short_url})"
    else
      puts "skipping missing upload in #{post.full_url} #{$1}"
      $1
    end
  end

  if replaced
    puts "Corrected image urls in #{post.full_url} raw backup stored in custom field"
    post.custom_fields["BACKUP_POST_RAW"] = original_raw
    post.save_custom_fields
    post.save!(validate: false)
    post.rebake!
  end
end

def fix_relative_links
  Post.where('raw like ?', '%](/uploads%').find_each do |post|
    inline_uploads(post)
  end
  Post.where("raw ilike ?", '%<img%src=%/uploads/%>%').find_each do |post|
    inline_img_tags(post)
  end
end

task "uploads:fix_relative_upload_links" => :environment do
  if RailsMultisite::ConnectionManagement.current_db != "default"
    fix_relative_links
  else
    RailsMultisite::ConnectionManagement.each_connection do
      fix_relative_links
    end
  end
end

def analyze_missing_s3
  puts "List of posts with missing images:"
  sql = <<~SQL
    SELECT post_id, url, sha1, extension, uploads.id
    FROM post_uploads pu
    RIGHT JOIN uploads on uploads.id = pu.upload_id
    WHERE verification_status = :invalid_etag
    ORDER BY created_at
  SQL

  lookup = {}
  other = []
  all = []

  DB.query(sql, invalid_etag: Upload.verification_statuses[:invalid_etag]).each do |r|
    all << r
    if r.post_id
      lookup[r.post_id] ||= []
      lookup[r.post_id] << [r.url, r.sha1, r.extension]
    else
      other << r
    end
  end

  posts = Post.where(id: lookup.keys)
  posts.order(:created_at).each do |post|
    puts "#{Discourse.base_url}/p/#{post.id} #{lookup[post.id].length} missing, #{post.created_at}"
    lookup[post.id].each do |url, sha1, extension|
      puts url
      puts "#{Upload.base62_sha1(sha1)}.#{extension}"
    end
    puts
  end

  missing_uploads = Upload.where(verification_status: Upload.verification_statuses[:invalid_etag])
  puts "Total missing uploads: #{missing_uploads.count}, newest is #{missing_uploads.maximum(:created_at)}"
  puts "Total problem posts: #{lookup.keys.count} with #{lookup.values.sum { |a| a.length } } missing uploads"
  puts "Other missing uploads count: #{other.count}"

  if all.count > 0
    ids = all.map { |r| r.id }

    lookups = [
      [:post_uploads, :upload_id],
      [:users, :uploaded_avatar_id],
      [:user_avatars, :gravatar_upload_id],
      [:user_avatars, :custom_upload_id],
      [:site_settings, ["NULLIF(value, '')::integer", "data_type = #{SiteSettings::TypeSupervisor.types[:upload].to_i}"]],
      [:user_profiles, :profile_background_upload_id],
      [:user_profiles, :card_background_upload_id],
      [:categories, :uploaded_logo_id],
      [:categories, :uploaded_background_id],
      [:custom_emojis, :upload_id],
      [:theme_fields, :upload_id],
      [:user_exports, :upload_id],
      [:groups, :flair_upload_id],
    ]

    lookups.each do |table, (column, where)|
      count = DB.query_single(<<~SQL, ids: ids).first
        SELECT COUNT(*) FROM #{table} WHERE #{column} IN (:ids) #{"AND #{where}" if where}
      SQL
      if count > 0
        puts "Found #{count} missing row#{"s" if count > 1} in #{table}(#{column})"
      end
    end

  end

end

def delete_missing_s3
  missing = Upload.where(
    verification_status: Upload.verification_statuses[:invalid_etag]
  ).order(:created_at)
  count = missing.count
  if count > 0
    puts "The following uploads will be deleted from the database"
    missing.each do |upload|
      puts "#{upload.id} - #{upload.url} - #{upload.created_at}"
    end
    puts "Please confirm you wish to delete #{count} upload records by typing YES"
    confirm = STDIN.gets.strip
    if confirm == "YES"
      missing.destroy_all
      puts "#{count} records were deleted"
    else
      STDERR.puts "Aborting"
      exit 1
    end
  end
end

task "uploads:delete_missing_s3" => :environment do
  if RailsMultisite::ConnectionManagement.current_db != "default"
    delete_missing_s3
  else
    RailsMultisite::ConnectionManagement.each_connection do
      delete_missing_s3
    end
  end
end

task "uploads:analyze_missing_s3" => :environment do
  if RailsMultisite::ConnectionManagement.current_db != "default"
    analyze_missing_s3
  else
    RailsMultisite::ConnectionManagement.each_connection do
      analyze_missing_s3
    end
  end
end

def fix_missing_s3
  Jobs.run_immediately!

  puts "Attempting to download missing uploads and recreate"
  ids = Upload.where(
    verification_status: Upload.verification_statuses[:invalid_etag]
  ).pluck(:id)
  ids.each do |id|
    upload = Upload.find_by(id: id)
    next if !upload

    tempfile = nil
    downloaded_from = nil

    begin
      tempfile = FileHelper.download(upload.url, max_file_size: 30.megabyte, tmp_file_name: "#{SecureRandom.hex}.#{upload.extension}")
      downloaded_from = upload.url
    rescue => e
      if upload.origin.present?
        begin
          tempfile = FileHelper.download(upload.origin, max_file_size: 30.megabyte, tmp_file_name: "#{SecureRandom.hex}.#{upload.extension}")
          downloaded_from = upload.origin
        rescue => e
          puts "Failed to download #{upload.origin} #{e}"
        end
      else
        puts "Failed to download #{upload.url} #{e}"
      end
    end

    if tempfile
      puts "Successfully downloaded upload id: #{upload.id} - #{downloaded_from} fixing upload"

      fixed_upload = nil
      fix_error = nil
      Upload.transaction do
        begin
          upload.update_column(:sha1, SecureRandom.hex)
          fixed_upload = UploadCreator.new(tempfile, "temp.#{upload.extension}", skip_validations: true).create_for(Discourse.system_user.id)
        rescue => fix_error
          # invalid extension is the most common issue
        end
        raise ActiveRecord::Rollback
      end

      if fix_error
        puts "Failed to fix upload #{fix_error}"
      else
        # we do not fix sha, it may be wrong for arbitrary reasons, if we correct it
        # we may end up breaking posts
        save_error = nil
        begin
          upload.assign_attributes(etag: fixed_upload.etag, url: fixed_upload.url, verification_status: Upload.verification_statuses[:unchecked])
          upload.save!(validate: false)
        rescue => save_error
          # url might be null
        end

        if save_error
          puts "Failed to save upload #{save_error}"
        else
          OptimizedImage.where(upload_id: upload.id).destroy_all
          rebake_ids = PostUpload.where(upload_id: upload.id).pluck(:post_id)

          if rebake_ids.present?
            Post.where(id: rebake_ids).each do |post|
              puts "rebake post #{post.id}"
              post.rebake!
            end
          end
        end
      end
    end
  end

  puts "Attempting to automatically fix problem uploads"
  puts
  puts "Rebaking posts with missing uploads, this can take a while as all rebaking runs inline"

  sql = <<~SQL
    SELECT post_id
    FROM post_uploads pu
    JOIN uploads on uploads.id = pu.upload_id
    WHERE verification_status = :invalid_etag
    ORDER BY post_id DESC
  SQL

  DB.query_single(sql, invalid_etag: Upload.verification_statuses[:invalid_etag]).each do |post_id|
    post = Post.find_by(id: post_id)
    if post
      post.rebake!
      print "."
    else
      puts "Skipping #{post_id} since it is deleted"
    end
  end
  puts
end

task "uploads:fix_missing_s3" => :environment do
  if RailsMultisite::ConnectionManagement.current_db != "default"
    fix_missing_s3
  else
    RailsMultisite::ConnectionManagement.each_connection do
      fix_missing_s3
    end
  end
end
