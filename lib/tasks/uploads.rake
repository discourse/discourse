# frozen_string_literal: true

require "db_helper"
require "digest/sha1"
require "base62"

################################################################################
#                                    gather                                    #
################################################################################

require "rake_helpers"

task "uploads:gather" => :environment do
  ENV["RAILS_DB"] ? gather_uploads : gather_uploads_for_all_sites
end

def gather_uploads_for_all_sites
  RailsMultisite::ConnectionManagement.each_connection { gather_uploads }
end

def file_exists?(path)
  File.exist?(path) && File.size(path) > 0
rescue StandardError
  false
end

def gather_uploads
  public_directory = "#{Rails.root}/public"
  current_db = RailsMultisite::ConnectionManagement.current_db

  puts "", "Gathering uploads for '#{current_db}'...", ""

  Upload
    .where("url ~ '^\/uploads\/'")
    .where("url !~ ?", "^\/uploads\/#{current_db}")
    .find_each do |upload|
      begin
        old_db = upload.url[%r{\A/uploads/([^/]+)/}, 1]
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
      rescue StandardError
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
    Upload
      .where(sha1: nil)
      .find_each do |u|
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
  STDOUT.puts(
    "Please note that migrating to S3 is currently not reversible! \n[CTRL+c] to cancel, [ENTER] to continue",
  )
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

  queued_jobs = Sidekiq::Stats.new.queues.sum { |_, x| x }
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

  puts <<~TEXT
  This task will remove upload records and files permanently.

  Would you like to take a full backup before the clean up? (Y/N)
  TEXT

  if STDIN.gets.chomp.downcase == "y"
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

  uploads_directory = File.join(public_directory, "uploads", db).to_s

  # avatars (no avatar should be stored in that old directory)
  FileUtils.rm_rf("#{uploads_directory}/avatars")

  # uploads and optimized images
  Dir
    .glob("#{uploads_directory}/**/*.*")
    .each do |file_path|
      sha1 = Upload.generate_digest(file_path)
      url = file_path.split(public_directory, 2)[1]

      if (Upload.where(sha1: sha1).empty? && Upload.where(url: url).empty?) &&
           (OptimizedImage.where(sha1: sha1).empty? && OptimizedImage.where(url: url).empty?)
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
    list_missing_uploads(skip_optimized: ENV["SKIP_OPTIMIZED"])
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
        list_missing_uploads(skip_optimized: ENV["SKIP_OPTIMIZED"])
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
    default_scope.where("optimized_images.upload_id IN (?)", avatar_upload_ids),
    default_scope
      .where("optimized_images.upload_id NOT IN (?)", avatar_upload_ids)
      .where("LENGTH(COALESCE(url, '')) > 0")
      .where("width > 0 AND height > 0"),
  ].each do |scope|
    scope.find_each do |optimized_image|
      upload = optimized_image.upload

      next unless optimized_image.url =~ %r{\A/[^/]}
      next unless upload.url =~ %r{\A/[^/]}

      thumbnail = "#{public_directory}#{optimized_image.url}"
      original = "#{public_directory}#{upload.url}"

      if !File.exist?(thumbnail) || File.size(thumbnail) <= 0
        # make sure the original image exists locally
        if (!File.exist?(original) || File.size(original) <= 0) && upload.origin.present?
          # try to fix it by redownloading it
          begin
            downloaded =
              begin
                FileHelper.download(
                  upload.origin,
                  max_file_size: SiteSetting.max_image_size_kb.kilobytes,
                  tmp_file_name: "discourse-missing",
                  follow_redirect: true,
                )
              rescue StandardError
                nil
              end
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
          if upload.extension == "svg"
            FileUtils.cp(original, thumbnail)
          else
            OptimizedImage.resize(
              original,
              thumbnail,
              optimized_image.width,
              optimized_image.height,
            )
          end
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
  puts "Migration stopped!"
end

task "uploads:analyze", %i[cache_path limit] => :environment do |_, args|
  now = Time.zone.now
  current_db = RailsMultisite::ConnectionManagement.current_db

  puts "Analyzing uploads for '#{current_db}'... This may take awhile...\n"
  cache_path = args[:cache_path]

  current_db = RailsMultisite::ConnectionManagement.current_db
  uploads_path = Rails.root.join("public", "uploads", current_db)

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

  File
    .readlines(path)
    .each do |line|
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

  puts <<~TEXT
  Report for '#{current_db}'
  -----------#{"-" * current_db.length}
  Number of `Upload` records in DB: #{uploads_count}
  Number of `OptimizedImage` records in DB: #{optimized_images_count}
  **Total DB records: #{uploads_count + optimized_images_count}**

  Number of images in uploads folder: #{paths_count}
  ------------------------------------#{"-" * paths_count.to_s.length}

  TEXT

  helper = Class.new { include ActionView::Helpers::NumberHelper }

  helper = helper.new

  printf "%-15s | %-15s | %-15s\n", "extname", "total size", "count"
  puts "-" * 45

  extensions
    .sort_by { |_, value| value["size"] }
    .reverse
    .each do |extname, value|
      printf "%-15s | %-15s | %-15s\n",
             extname,
             helper.number_to_human_size(value["size"]),
             value["count"]
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
  printf "%-25s | %-25s | %-25s | %-25s\n",
         "username",
         "total size of uploads",
         "number of uploads",
         "number of optimized images"
  puts "-" * 110

  DB
    .query_single(sql)
    .each do |username, num_of_uploads, total_size_of_uploads, num_of_optimized_images|
      printf "%-25s | %-25s | %-25s | %-25s\n",
             username,
             helper.number_to_human_size(total_size_of_uploads),
             num_of_uploads,
             num_of_optimized_images
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

    puts "CAUTION: This task may take a long time to complete! There are #{Upload.count} uploads to sync ACLs for."
    puts ""
    puts "-" * 30
    puts "Uploads marked as secure will get a private ACL, and uploads marked as not secure will get a public ACL."
    puts "Upload ACLs will be updated in Sidekiq jobs in batches of 100 at a time, check Sidekiq queues for SyncAclsForUploads for progress."
    Upload.select(:id).find_in_batches(batch_size: 100) { |uploads| adjust_acls(uploads.map(&:id)) }
    puts "", "Upload ACL sync complete!"
  end
end

def secure_upload_rebake_warning
  puts "This task may mark a lot of posts for rebaking. To get through these quicker, the max_old_rebakes_per_15_minutes global setting (current value #{GlobalSetting.max_old_rebakes_per_15_minutes}) should be changed and the rebake_old_posts_count site setting (current value #{SiteSetting.rebake_old_posts_count}) increased as well. Do you want to proceed? (y/n)"
end

# NOTE: This needs to be updated to use the _first_ UploadReference
# record for each upload to determine security, and do not mark things
# as secure if the first record is something public e.g. a site setting.
#
# Alternatively, we need to overhaul this rake task to work with whatever
# other strategy we come up with for secure uploads.
task "uploads:disable_secure_uploads" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    unless Discourse.store.external?
      puts "This task only works for external storage."
      exit 1
    end

    secure_upload_rebake_warning
    exit 1 if STDIN.gets.chomp.downcase != "y"

    puts "Disabling secure upload and resetting uploads to not secure in #{db}...", ""

    SiteSetting.secure_uploads = false

    secure_uploads =
      Upload
        .joins(:upload_references)
        .where(upload_references: { target_type: "Post" })
        .where(secure: true)
    secure_upload_count = secure_uploads.count
    secure_upload_ids = secure_uploads.pluck(:id)

    puts "", "Marking #{secure_upload_count} uploads as not secure.", ""
    secure_uploads.update_all(
      secure: false,
      security_last_changed_at: Time.zone.now,
      security_last_changed_reason: "marked as not secure by disable_secure_uploads task",
    )

    post_ids_to_rebake =
      DB.query_single(
        "SELECT DISTINCT target_id FROM upload_references WHERE upload_id IN (?) AND target_type = 'Post'",
        secure_upload_ids,
      )
    adjust_acls(secure_upload_ids)
    mark_upload_posts_for_rebake(post_ids_to_rebake)

    puts "", "Rebaking and uploading complete!", ""
  end

  puts "", "Secure uploads are now disabled!", ""
end

##
# Run this task whenever the secure_uploads or login_required
# settings are changed for a Discourse instance to update
# the upload secure flag and S3 upload ACLs. Any uploads that
# have their secure status changed will have all associated posts
# rebaked.
#
# NOTE: This needs to be updated to use the _first_ UploadReference
# record for each upload to determine security, and do not mark things
# as secure if the first record is something public e.g. a site setting.
#
# Alternatively, we need to overhaul this rake task to work with whatever
# other strategy we come up with for secure uploads.
task "uploads:secure_upload_analyse_and_update" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    unless Discourse.store.external?
      puts "This task only works for external storage."
      exit 1
    end

    secure_upload_rebake_warning
    exit 1 if STDIN.gets.chomp.downcase != "y"

    puts "Analyzing security for uploads in #{db}...", ""
    all_upload_ids_changed, post_ids_to_rebake = nil
    Upload.transaction do
      # If secure upload is enabled we need to first set the access control post of
      # all post uploads (even uploads that are linked to multiple posts). If the
      # upload is not set to secure upload then this has no other effect on the upload,
      # but we _must_ know what the access control post is because the should_secure_uploads?
      # method is on the post, and this knows about the category security & PM status
      update_uploads_access_control_post if SiteSetting.secure_uploads?

      puts "", "Analysing which uploads need to be marked secure and be rebaked.", ""
      if SiteSetting.login_required? && !SiteSetting.secure_uploads_pm_only?
        # Simply mark all uploads linked to posts secure if login_required because
        # no anons will be able to access them; however if secure_uploads_pm_only is
        # true then login_required will not mark other uploads secure.
        puts "",
             "Site is login_required, and secure_uploads_pm_only is false. Continuing with strategy to mark all post uploads as secure.",
             ""
        post_ids_to_rebake, all_upload_ids_changed = mark_all_as_secure_login_required
      else
        # Otherwise only mark uploads linked to posts either:
        #   * In secure categories or PMs if !SiteSetting.secure_uploads_pm_only
        #   * In PMs if SiteSetting.secure_uploads_pm_only
        puts "",
             "Site is not login_required. Continuing with normal strategy to mark uploads in secure contexts as secure.",
             ""
        post_ids_to_rebake, all_upload_ids_changed =
          update_specific_upload_security_no_login_required
      end
    end

    # Enqueue rebakes AFTER upload transaction complete, so there is no race condition
    # between updating the DB and the rebakes occurring.
    #
    # This is done asynchronously by changing the baked_version to NULL on
    # affected posts and relying on Post.rebake_old in the PeriodicalUpdates
    # job. To speed this up, these levers can be adjusted:
    #
    # * SiteSetting.rebake_old_posts_count
    # * GlobalSetting.max_old_rebakes_per_15_minutes
    mark_upload_posts_for_rebake(post_ids_to_rebake)

    # Also do this AFTER upload transaction complete so we don't end up with any
    # errors leaving ACLs in a bad state (the ACL sync task can be run to fix any
    # outliers at any time).
    adjust_acls(all_upload_ids_changed)
  end
  puts "", "", "Done!"
end

def adjust_acls(upload_ids_to_adjust_acl_for)
  jobs_to_create = (upload_ids_to_adjust_acl_for.count.to_f / 100.00).ceil

  if jobs_to_create > 1
    puts "Adjusting ACLs for #{upload_ids_to_adjust_acl_for} uploads. These will be batched across #{jobs_to_create} sync job(s)."
  end

  upload_ids_to_adjust_acl_for.each_slice(100) do |upload_ids|
    Jobs.enqueue(:sync_acls_for_uploads, upload_ids: upload_ids)
  end

  puts "ACL batching complete. Keep an eye on the Sidekiq queue for progress." if jobs_to_create > 1
end

def mark_all_as_secure_login_required
  post_upload_ids_marked_secure = DB.query_single(<<~SQL)
    WITH upl AS (
      SELECT DISTINCT ON (upload_id) upload_id
      FROM upload_references
      INNER JOIN posts ON posts.id = upload_references.target_id AND upload_references.target_type = 'Post'
      INNER JOIN topics ON topics.id = posts.topic_id
    )
    UPDATE uploads
    SET secure = true,
        security_last_changed_reason = 'upload security rake task mark as secure',
        security_last_changed_at = NOW()
    FROM upl
    WHERE uploads.id = upl.upload_id
    RETURNING uploads.id
  SQL
  puts "Marked #{post_upload_ids_marked_secure.count} upload(s) as secure because login_required is true.",
       ""
  upload_ids_marked_not_secure = DB.query_single(<<~SQL, post_upload_ids_marked_secure)
    UPDATE uploads
    SET secure = false,
        security_last_changed_reason = 'upload security rake task mark as not secure',
        security_last_changed_at = NOW()
    WHERE id NOT IN (?)
    RETURNING uploads.id
  SQL
  puts "Marked #{upload_ids_marked_not_secure.count} upload(s) as not secure because they are not linked to posts.",
       ""
  puts "Finished marking upload(s) as secure."

  post_ids_to_rebake =
    DB.query_single(
      "SELECT DISTINCT target_id FROM upload_references WHERE upload_id IN (?) AND target_type = 'Post'",
      post_upload_ids_marked_secure,
    )
  [post_ids_to_rebake, (post_upload_ids_marked_secure + upload_ids_marked_not_secure).uniq]
end

def log_rebake_errors(rebake_errors)
  return if rebake_errors.empty?
  puts "The following post rebakes failed with error:", ""
  rebake_errors.each { |message| puts message }
end

def update_specific_upload_security_no_login_required
  # A simplification of the rules found in UploadSecurity which is a lot faster than
  # having to loop through records and use that class to check security.
  filter_clause =
    if SiteSetting.secure_uploads_pm_only?
      "WHERE topics.archetype = 'private_message'"
    else
      <<~SQL
        LEFT JOIN categories ON categories.id = topics.category_id
        WHERE (topics.category_id IS NOT NULL AND categories.read_restricted) OR
          (topics.archetype = 'private_message')
      SQL
    end

  post_upload_ids_marked_secure = DB.query_single(<<~SQL)
    WITH upl AS (
      SELECT DISTINCT ON (upload_id) upload_id
      FROM upload_references
      INNER JOIN posts ON posts.id = upload_references.target_id AND upload_references.target_type = 'Post'
      INNER JOIN topics ON topics.id = posts.topic_id
      #{filter_clause}
    )
    UPDATE uploads
    SET secure = true,
        security_last_changed_reason = 'upload security rake task mark as secure',
        security_last_changed_at = NOW()
    FROM upl
    WHERE uploads.id = upl.upload_id AND NOT uploads.secure
    RETURNING uploads.id
  SQL
  puts "Marked #{post_upload_ids_marked_secure.length} uploads as secure."

  # Anything in a public category or a regular topic should not be secure.
  post_upload_ids_marked_not_secure = DB.query_single(<<~SQL)
    WITH upl AS (
      SELECT DISTINCT ON (upload_id) upload_id
      FROM upload_references
      INNER JOIN posts ON posts.id = upload_references.target_id AND upload_references.target_type = 'Post'
      INNER JOIN topics ON topics.id = posts.topic_id
      LEFT JOIN categories ON categories.id = topics.category_id
      WHERE (topics.archetype = 'regular' AND topics.category_id IS NOT NULL AND NOT categories.read_restricted) OR
            (topics.archetype = 'regular' AND topics.category_id IS NULL)
    )
    UPDATE uploads
    SET secure = false,
        security_last_changed_reason = 'upload security rake task mark as not secure',
        security_last_changed_at = NOW()
    FROM upl
    WHERE uploads.id = upl.upload_id AND uploads.secure
    RETURNING uploads.id
  SQL
  puts "Marked #{post_upload_ids_marked_not_secure.length} uploads as not secure."

  # Everything else should not be secure!
  upload_ids_changed = (post_upload_ids_marked_secure + post_upload_ids_marked_not_secure).uniq
  upload_ids_marked_not_secure = DB.query_single(<<~SQL, upload_ids_changed)
    UPDATE uploads
    SET secure = false,
        security_last_changed_reason = 'upload security rake task mark as not secure',
        security_last_changed_at = NOW()
    WHERE id NOT IN (?) AND uploads.secure
    RETURNING uploads.id
  SQL
  puts "Finished updating upload security. Marked #{upload_ids_marked_not_secure.length} uploads not linked to posts as not secure."

  all_upload_ids_changed = (upload_ids_changed + upload_ids_marked_not_secure).uniq
  post_ids_to_rebake =
    DB.query_single(
      "SELECT DISTINCT target_id FROM upload_references WHERE upload_id IN (?) AND target_type = 'Post'",
      upload_ids_changed,
    )
  [post_ids_to_rebake, all_upload_ids_changed]
end

def update_uploads_access_control_post
  DB.exec(<<~SQL)
    WITH upl AS (
      SELECT DISTINCT ON (upload_id) upload_id, target_id AS post_id
      FROM upload_references
      WHERE target_type = 'Post'
      ORDER BY upload_id, target_id
    )
    UPDATE uploads
    SET access_control_post_id = upl.post_id
    FROM upl
    WHERE uploads.id = upl.upload_id
  SQL
end

def mark_upload_posts_for_rebake(post_ids_to_rebake)
  posts_to_rebake = Post.where(id: post_ids_to_rebake)
  post_rebake_errors = []
  puts "",
       "Marking #{posts_to_rebake.length} posts with affected uploads for rebake. Every 15 minutes, a batch of these will be enqueued for rebaking.",
       ""
  posts_to_rebake.update_all(baked_version: nil)
  File.write(
    "secure_upload_analyse_and_update_posts_for_rebake.json",
    MultiJson.dump({ post_ids: post_ids_to_rebake }),
  )
  puts "",
       "Post IDs written to secure_upload_analyse_and_update_posts_for_rebake.json for reference",
       ""
end

def inline_uploads(post)
  replaced = false

  original_raw = post.raw

  post.raw =
    post
      .raw
      .gsub(%r{(\((/uploads\S+).*\))}) do
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
  post.raw =
    post
      .raw
      .gsub(%r{(<img\s+src=["'](/uploads/[^'"]*)["'].*>)}i) do
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
  Post.where("raw like ?", "%](/uploads%").find_each { |post| inline_uploads(post) }
  Post.where("raw ilike ?", "%<img%src=%/uploads/%>%").find_each { |post| inline_img_tags(post) }
end

task "uploads:fix_relative_upload_links" => :environment do
  if RailsMultisite::ConnectionManagement.current_db != "default"
    fix_relative_links
  else
    RailsMultisite::ConnectionManagement.each_connection { fix_relative_links }
  end
end

def analyze_missing_s3
  puts "List of posts with missing images:"
  sql = <<~SQL
    SELECT ur.target_id, u.url, u.sha1, u.extension, u.id
    FROM upload_references ur
    RIGHT JOIN uploads u ON u.id = ur.upload_id
    WHERE ur.target_type = 'Post' AND u.verification_status = :invalid_etag
    ORDER BY ur.created_at
  SQL

  lookup = {}
  other = []
  all = []

  DB
    .query(sql, invalid_etag: Upload.verification_statuses[:invalid_etag])
    .each do |r|
      all << r
      if r.target_id
        lookup[r.target_id] ||= []
        lookup[r.target_id] << [r.url, r.sha1, r.extension]
      else
        other << r
      end
    end

  posts = Post.where(id: lookup.keys)
  posts
    .order(:created_at)
    .each do |post|
      puts "#{Discourse.base_url}/p/#{post.id} #{lookup[post.id].length} missing, #{post.created_at}"
      lookup[post.id].each do |url, sha1, extension|
        puts url
        puts "#{Upload.base62_sha1(sha1)}.#{extension}"
      end
      puts
    end

  missing_uploads = Upload.with_invalid_etag_verification_status
  puts "Total missing uploads: #{missing_uploads.count}, newest is #{missing_uploads.maximum(:created_at)}"
  puts "Total problem posts: #{lookup.keys.count} with #{lookup.values.sum { |a| a.length }} missing uploads"
  puts "Other missing uploads count: #{other.count}"

  if all.count > 0
    ids = all.map { |r| r.id }

    lookups = [
      %i[upload_references upload_id],
      %i[users uploaded_avatar_id],
      %i[user_avatars gravatar_upload_id],
      %i[user_avatars custom_upload_id],
      [
        :site_settings,
        [
          "NULLIF(value, '')::integer",
          "data_type = #{SiteSettings::TypeSupervisor.types[:upload].to_i}",
        ],
      ],
      %i[user_profiles profile_background_upload_id],
      %i[user_profiles card_background_upload_id],
      %i[categories uploaded_logo_id],
      %i[categories uploaded_logo_dark_id],
      %i[categories uploaded_background_id],
      %i[categories uploaded_background_dark_id],
      %i[custom_emojis upload_id],
      %i[theme_fields upload_id],
      %i[user_exports upload_id],
      %i[groups flair_upload_id],
    ]

    lookups.each do |table, (column, where)|
      count = DB.query_single(<<~SQL, ids: ids).first
        SELECT COUNT(*) FROM #{table} WHERE #{column} IN (:ids) #{"AND #{where}" if where}
      SQL
      puts "Found #{count} missing row#{"s" if count > 1} in #{table}(#{column})" if count > 0
    end
  end
end

def delete_missing_s3
  missing = Upload.with_invalid_etag_verification_status.order(:created_at)
  count = missing.count

  if count > 0
    puts "The following uploads will be deleted from the database"
    missing.each { |upload| puts "#{upload.id} - #{upload.url} - #{upload.created_at}" }
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

task "uploads:mark_invalid_s3_uploads_as_missing" => :environment do
  puts "Marking invalid S3 uploads as missing for '#{RailsMultisite::ConnectionManagement.current_db}'..."
  invalid_s3_uploads = Upload.with_invalid_etag_verification_status.order(:created_at)
  count = invalid_s3_uploads.count

  if count > 0
    puts "The following uploads will be marked as missing on S3"
    invalid_s3_uploads.each { |upload| puts "#{upload.id} - #{upload.url} - #{upload.created_at}" }
    puts "Please confirm you wish to mark #{count} upload records as missing by typing YES"
    confirm = STDIN.gets.strip

    if confirm == "YES"
      changed_count = Upload.mark_invalid_s3_uploads_as_missing
      puts "#{changed_count} records were marked as missing"
    else
      STDERR.puts "Aborting"
      exit 1
    end
  else
    puts "No uploads found with invalid S3 etag verification status"
  end
end

task "uploads:delete_missing_s3" => :environment do
  if RailsMultisite::ConnectionManagement.current_db != "default"
    delete_missing_s3
  else
    RailsMultisite::ConnectionManagement.each_connection { delete_missing_s3 }
  end
end

task "uploads:analyze_missing_s3" => :environment do
  if RailsMultisite::ConnectionManagement.current_db != "default"
    analyze_missing_s3
  else
    RailsMultisite::ConnectionManagement.each_connection { analyze_missing_s3 }
  end
end

def fix_missing_s3
  Jobs.run_immediately!

  puts "Attempting to download missing uploads and recreate"
  ids = Upload.with_invalid_etag_verification_status.pluck(:id)
  ids.each do |id|
    upload = Upload.find_by(id: id)
    next if !upload

    tempfile = nil
    downloaded_from = nil

    begin
      tempfile =
        FileHelper.download(
          upload.url,
          max_file_size: 30.megabyte,
          tmp_file_name: "#{SecureRandom.hex}.#{upload.extension}",
        )
      downloaded_from = upload.url
    rescue => e
      if upload.origin.present?
        begin
          tempfile =
            FileHelper.download(
              upload.origin,
              max_file_size: 30.megabyte,
              tmp_file_name: "#{SecureRandom.hex}.#{upload.extension}",
            )
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
          fixed_upload =
            UploadCreator.new(
              tempfile,
              "temp.#{upload.extension}",
              skip_validations: true,
            ).create_for(Discourse.system_user.id)
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
          upload.assign_attributes(
            etag: fixed_upload.etag,
            url: fixed_upload.url,
            verification_status: Upload.verification_statuses[:unchecked],
          )
          upload.save!(validate: false)
        rescue => save_error
          # url might be null
        end

        if save_error
          puts "Failed to save upload #{save_error}"
        else
          OptimizedImage.where(upload_id: upload.id).destroy_all
          rebake_ids =
            UploadReference.where(upload_id: upload.id).where(target_type: "Post").pluck(:target_id)

          if rebake_ids.present?
            Post
              .where(id: rebake_ids)
              .each do |post|
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
    SELECT ur.target_id
    FROM upload_references ur
    JOIN uploads u ON u.id = ur.upload_id
    WHERE ur.target_type = 'Post' AND u.verification_status = :invalid_etag
    ORDER BY ur.target_id DESC
  SQL

  DB
    .query_single(sql, invalid_etag: Upload.verification_statuses[:invalid_etag])
    .each do |post_id|
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
    RailsMultisite::ConnectionManagement.each_connection { fix_missing_s3 }
  end
end

# Supported ENV arguments:
#
# VERBOSE=1
# Shows debug information.
#
# INTERACTIVE=1
# Shows debug information and pauses for input on issues.
#
# WORKER_ID/WORKER_COUNT
# When running the script on a single forum in multiple terminals.
# For example, if you want 4 concurrent scripts use WORKER_COUNT=4
# and WORKER_ID from 0 to 3.
#
# START_ID
# Skip uploads with id lower than START_ID.
task "uploads:downsize" => :environment do
  min_image_pixels = 500_000 # 0.5 megapixels
  default_image_pixels = 1_000_000 # 1 megapixel

  max_image_pixels = [ARGV[0]&.to_i || default_image_pixels, min_image_pixels].max

  ENV["VERBOSE"] = "1" if ENV["INTERACTIVE"]

  def log(*args)
    puts(*args) if ENV["VERBOSE"]
  end

  puts "", "Downsizing images to no more than #{max_image_pixels} pixels"

  dimensions_count = 0
  downsized_count = 0

  scope =
    Upload.by_users.with_no_non_post_relations.where(
      "LOWER(extension) IN ('jpg', 'jpeg', 'gif', 'png')",
    )

  scope = scope.where(<<-SQL, max_image_pixels)
    COALESCE(width, 0) = 0 OR
    COALESCE(height, 0) = 0 OR
    COALESCE(thumbnail_width, 0) = 0 OR
    COALESCE(thumbnail_height, 0) = 0 OR
    width * height > ?
  SQL

  if ENV["WORKER_ID"] && ENV["WORKER_COUNT"]
    scope = scope.where("uploads.id % ? = ?", ENV["WORKER_COUNT"], ENV["WORKER_ID"])
  end

  scope = scope.where("uploads.id >= ?", ENV["START_ID"]) if ENV["START_ID"]

  skipped = 0
  total_count = scope.count
  puts "Uploads to process: #{total_count}"

  scope.find_each.with_index do |upload, index|
    progress = (index * 100.0 / total_count).round(1)

    log "\n"
    print "\r#{progress}% Fixed dimensions: #{dimensions_count} Downsized: #{downsized_count} Skipped: #{skipped} (upload id: #{upload.id})"
    log "\n"

    path =
      if upload.local?
        Discourse.store.path_for(upload)
      else
        Discourse.store.download_safe(upload, max_file_size_kb: 100.megabytes)&.path
      end

    unless path
      log "No image path"
      skipped += 1
      next
    end

    begin
      w, h = FastImage.size(path, raise_on_failure: true)
    rescue FastImage::UnknownImageType
      log "Unknown image type"
      skipped += 1
      next
    rescue FastImage::SizeNotFound
      log "Size not found"
      skipped += 1
      next
    end

    if !w || !h
      log "Invalid image dimensions"
      skipped += 1
      next
    end

    ww, hh = ImageSizer.resize(w, h)

    if w == 0 || h == 0 || ww == 0 || hh == 0
      log "Invalid image dimensions"
      skipped += 1
      next
    end

    upload.attributes = {
      width: w,
      height: h,
      thumbnail_width: ww,
      thumbnail_height: hh,
      filesize: File.size(path),
    }

    if upload.changed?
      log "Correcting the upload dimensions"
      log "Before: #{upload.width_was}x#{upload.height_was} #{upload.thumbnail_width_was}x#{upload.thumbnail_height_was} (#{upload.filesize_was})"
      log "After:  #{w}x#{h} #{ww}x#{hh} (#{upload.filesize})"

      dimensions_count += 1

      # Don't validate the size - max image size setting might have
      # changed since the file was uploaded, so this could fail
      upload.validate_file_size = false
      upload.save!
    end

    if w * h < max_image_pixels
      log "Image size within allowed range"
      skipped += 1
      next
    end

    result =
      ShrinkUploadedImage.new(
        upload: upload,
        path: path,
        max_pixels: max_image_pixels,
        verbose: ENV["VERBOSE"],
        interactive: ENV["INTERACTIVE"],
      ).perform

    if result
      downsized_count += 1
    else
      skipped += 1
    end
  end

  STDIN.beep
  puts "", "Done", Time.zone.now
end
