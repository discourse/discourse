require "digest/sha1"

################################################################################
#                                backfill_shas                                 #
################################################################################

task "uploads:backfill_shas" => :environment do
  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Backfilling #{db}"
    Upload.select([:id, :sha, :url]).find_each do |u|
      if u.sha.nil?
        putc "."
        path = "#{Rails.root}/public/#{u.url}"
        sha = Digest::SHA1.file(path).hexdigest
        begin
          Upload.update_all ["sha = ?", sha], ["id = ?", u.id]
        rescue ActiveRecord::RecordNotUnique
          # not a big deal if we've got a few duplicates
        end
      end
    end
  end
  puts "done"
end

################################################################################
#                               migrate_from_s3                                #
################################################################################

task "uploads:migrate_from_s3" => :environment do
  require "file_store/local_store"
  require "file_helper"

  max_file_size_kb = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes
  local_store = FileStore::LocalStore.new

  puts "Deleting all optimized images..."
  puts

  OptimizedImage.destroy_all

  puts "Migrating uploads from S3 to local storage"
  puts

  Upload.find_each do |upload|

    # remove invalid uploads
    if upload.url.blank?
      upload.destroy!
      next
    end

    # no need to download an upload twice
    if local_store.has_been_uploaded?(upload.url)
      putc "."
      next
    end

    # try to download the upload
    begin
      # keep track of the previous url
      previous_url = upload.url
      # fix the name of pasted images
      upload.original_filename = "blob.png" if upload.original_filename == "blob"
      # download the file (in a temp file)
      temp_file = FileHelper.download("http:" + previous_url, max_file_size_kb, "from_s3")
      # store the file locally
      upload.url = local_store.store_upload(temp_file, upload)
      # save the new url
      if upload.save
        # update & rebake the posts (if any)
        Post.where("raw ILIKE ?", "%#{previous_url}%").find_each do |post|
          post.raw = post.raw.gsub(previous_url, upload.url)
          post.save
        end

        putc "#"
      else
        putc "X"
      end

      # close the temp_file
      temp_file.close! if temp_file.respond_to? :close!
    rescue
      putc "X"
    end

  end

  puts

end

################################################################################
#                                migrate_to_s3                                 #
################################################################################

task "uploads:migrate_to_s3" => :environment do
  require "file_store/s3_store"
  require "file_store/local_store"

  ENV["RAILS_DB"] ? migrate_to_s3 : migrate_to_s3_all_sites
end

def migrate_to_s3_all_sites
  RailsMultisite::ConnectionManagement.each_connection { migrate_to_s3 }
end

def migrate_to_s3
  # make sure s3 is enabled
  if !SiteSetting.enable_s3_uploads
    puts "You must enable s3 uploads before running that task"
    return
  end

  db = RailsMultisite::ConnectionManagement.current_db

  puts "Migrating uploads to S3 (#{SiteSetting.s3_upload_bucket}) for '#{db}'..."

  # will throw an exception if the bucket is missing
  s3 = FileStore::S3Store.new
  local = FileStore::LocalStore.new

  # Migrate all uploads
  Upload.where.not(sha1: nil)
        .where("url NOT LIKE '#{s3.absolute_base_url}%'")
        .find_each do |upload|
    # remove invalid uploads
    if upload.url.blank?
      upload.destroy!
      next
    end
    # store the old url
    from = upload.url
    # retrieve the path to the local file
    path = local.path_for(upload)
    # make sure the file exists locally
    if !File.exists?(path)
      putc "X"
      next
    end

    begin
      file = File.open(path)
      content_type = `file --mime-type -b #{path}`.strip
      to = s3.store_upload(file, upload, content_type)
    rescue
      putc "X"
      next
    ensure
      file.try(:close!) rescue nil
    end

    # remap the URL
    remap(from, to)

    putc "."
  end
end

################################################################################
#                                  clean_up                                   #
################################################################################

task "uploads:clean_up" => :environment do

  RailsMultisite::ConnectionManagement.each_connection do |db|
    puts "Cleaning up uploads and thumbnails for '#{db}'..."

    if Discourse.store.external?
      puts "This task only works for internal storages."
      next
    end

    public_directory = "#{Rails.root}/public"

    ##
    ## DATABASE vs FILE SYSTEM
    ##

    # uploads & avatars
    Upload.find_each do |upload|
      path = "#{public_directory}#{upload.url}"
      if !File.exists?(path)
        upload.destroy rescue nil
        putc "#"
      else
        putc "."
      end
    end

    # optimized images
    OptimizedImage.find_each do |optimized_image|
      path = "#{public_directory}#{optimized_image.url}"
      if !File.exists?(path)
        optimized_image.destroy rescue nil
        putc "#"
      else
        putc "."
      end
    end

    ##
    ## FILE SYSTEM vs DATABASE
    ##

    uploads_directory = "#{public_directory}/uploads/#{db}"

    # avatars (no avatar should be stored in that old directory)
    FileUtils.rm_rf("#{uploads_directory}/avatars") rescue nil

    # uploads
    Dir.glob("#{uploads_directory}/*/*.*").each do |f|
      url = "/uploads/#{db}/" << f.split("/uploads/#{db}/")[1]
      if !Upload.where(url: url).exists?
        FileUtils.rm(f) rescue nil
        putc "#"
      else
        putc "."
      end
    end

    # optimized images
    Dir.glob("#{uploads_directory}/_optimized/*/*/*.*").each do |f|
      url = "/uploads/#{db}/_optimized/" << f.split("/uploads/#{db}/_optimized/")[1]
      if !OptimizedImage.where(url: url).exists?
        FileUtils.rm(f) rescue nil
        putc "#"
      else
        putc "."
      end
    end

    puts

  end

end

################################################################################
#                                   missing                                    #
################################################################################

# list all missing uploads and optimized images
task "uploads:missing" => :environment do

  public_directory = "#{Rails.root}/public"

  RailsMultisite::ConnectionManagement.each_connection do |db|

    if Discourse.store.external?
      puts "This task only works for internal storages."
      next
    end


    Upload.find_each do |upload|

      # could be a remote image
      next unless upload.url =~ /^\/[^\/]/

      path = "#{public_directory}#{upload.url}"
      bad = true
      begin
        bad = false if File.size(path) != 0
      rescue
        # something is messed up
      end
      puts path if bad
    end

    OptimizedImage.find_each do |optimized_image|

      # remote?
      next unless optimized_image.url =~ /^\/[^\/]/

      path = "#{public_directory}#{optimized_image.url}"

      bad = true
      begin
        bad = false if File.size(path) != 0
      rescue
        # something is messed up
      end
      puts path if bad
    end

  end

end

################################################################################
#                        regenerate_missing_optimized                          #
################################################################################

# regenerate missing optimized images
task "uploads:regenerate_missing_optimized" => :environment do
  ENV["RAILS_DB"] ? regenerate_missing_optimized : regenerate_missing_optimized_all_sites
end

def regenerate_missing_optimized_all_sites
  RailsMultisite::ConnectionManagement.each_connection { regenerate_missing_optimized }
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

  OptimizedImage.includes(:upload)
                .where("LENGTH(COALESCE(url, '')) > 0")
                .where("width > 0 AND height > 0")
                .find_each do |optimized_image|

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
          downloaded = FileHelper.download(upload.origin, SiteSetting.max_image_size_kb.kilobytes, "discourse-missing", true) rescue nil
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

  puts "", "Done"

  if missing_uploads.size > 0
    puts "Missing uploads:"
    missing_uploads.sort.each { |u| puts u }
  end
end

################################################################################
#                           migrate_to_new_pattern                             #
################################################################################

task "uploads:migrate_to_new_pattern" => :environment do
  require "file_helper"
  require "file_store/local_store"

  ENV["RAILS_DB"] ? migrate_to_new_pattern : migrate_to_new_pattern_all_sites
end

def migrate_to_new_pattern_all_sites
  RailsMultisite::ConnectionManagement.each_connection { migrate_to_new_pattern }
end

def migrate_to_new_pattern
  db = RailsMultisite::ConnectionManagement.current_db

  puts "Migrating uploads to new pattern for '#{db}'..."
  migrate_uploads_to_new_pattern

  puts "Migrating optimized images to new pattern for '#{db}'..."
  migrate_optimized_images_to_new_pattern

  puts "Done!"
end

def migrate_uploads_to_new_pattern
  puts "Moving uploads to new location..."

  max_file_size_kb = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes
  local_store = FileStore::LocalStore.new

  Upload.where("LENGTH(COALESCE(url, '')) = 0").destroy_all

  Upload.where("url NOT LIKE '%/original/_X/%'").find_each do |upload|
    begin
      successful = false
      # keep track of the url
      previous_url = upload.url.dup
      # where is the file currently stored?
      external = previous_url =~ /^\/\//
      # download if external
      if external
        url = SiteSetting.scheme + ":" + previous_url
        file = FileHelper.download(url, max_file_size_kb, "discourse", true) rescue nil
        next unless file
        path = file.path
      else
        path = local_store.path_for(upload)
        next unless File.exists?(path)
      end
      # compute SHA if missing
      if upload.sha1.blank?
        upload.sha1 = Digest::SHA1.file(path).hexdigest
      end
      # optimize if image
      if FileHelper.is_image?(File.basename(path))
        ImageOptim.new.optimize_image!(path)
      end
      # store to new location & update the filesize
      File.open(path) do |f|
        upload.url = Discourse.store.store_upload(f, upload)
        upload.filesize = f.size
        upload.save
      end
      # remap the URLs
      remap(previous_url, upload.url)
      # remove the old file (when local)
      unless external
        FileUtils.rm(path, force: true) rescue nil
      end
      # succesfully migrated
      successful = true
    rescue => e
      puts e.message
      puts e.backtrace.join("\n")
    ensure
      putc successful ? '.' : 'X'
      file.try(:unlink) rescue nil
      file.try(:close) rescue nil
    end
  end

  puts
end

def migrate_optimized_images_to_new_pattern
  max_file_size_kb = SiteSetting.max_image_size_kb.kilobytes
  local_store = FileStore::LocalStore.new

  OptimizedImage.where("LENGTH(COALESCE(url, '')) = 0").destroy_all

  OptimizedImage.where("url NOT LIKE '%/original/_X/%'").find_each do |optimized_image|
    begin
      successful = false
      # keep track of the url
      previous_url = optimized_image.url.dup
      # where is the file currently stored?
      external = previous_url =~ /^\/\//
      # download if external
      if external
        url = SiteSetting.scheme + ":" + previous_url
        file = FileHelper.download(url, max_file_size_kb, "discourse", true) rescue nil
        next unless file
        path = file.path
      else
        path = local_store.path_for(optimized_image)
        next unless File.exists?(path)
        file = File.open(path)
      end
      # compute SHA if missing
      if optimized_image.sha1.blank?
        optimized_image.sha1 = Digest::SHA1.file(path).hexdigest
      end
      # optimize if image
      ImageOptim.new.optimize_image!(path)
      # store to new location & update the filesize
      File.open(path) do |f|
        optimized_image.url = Discourse.store.store_optimized_image(f, optimized_image)
        optimized_image.save
      end
      # remap the URLs
      remap(previous_url, optimized_image.url)
      # remove the old file (when local)
      unless external
        FileUtils.rm(path, force: true) rescue nil
      end
      # succesfully migrated
      successful = true
    rescue => e
      puts e.message
      puts e.backtrace.join("\n")
    ensure
      putc successful ? '.' : 'X'
      file.try(:unlink) rescue nil
      file.try(:close) rescue nil
    end
  end

  puts
end

REMAP_SQL ||= "
  SELECT table_name, column_name
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND is_updatable = 'YES'
     AND (data_type LIKE 'char%' OR data_type LIKE 'text%')
ORDER BY table_name, column_name
"

def remap(from, to)
  connection ||= ActiveRecord::Base.connection.raw_connection
  remappable_columns ||= connection.async_exec(REMAP_SQL).to_a

  remappable_columns.each do |rc|
    table_name = rc["table_name"]
    column_name = rc["column_name"]
    begin
      connection.async_exec("
        UPDATE #{table_name}
           SET #{column_name} = REPLACE(#{column_name}, $1, $2)
         WHERE #{column_name} IS NOT NULL
           AND #{column_name} <> REPLACE(#{column_name}, $1, $2)", [from, to])
    rescue
    end
  end
end
