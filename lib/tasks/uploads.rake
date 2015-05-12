require "digest/sha1"

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

task "uploads:migrate_from_s3" => :environment do
  require 'file_store/local_store'
  require 'file_helper'

  local_store = FileStore::LocalStore.new
  max_file_size = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes

  puts "Deleting all optimized images..."
  puts

  OptimizedImage.destroy_all

  puts "Migrating uploads from S3 to local storage"
  puts

  Upload.order(:id).find_each do |upload|

    # remove invalid uploads
    if upload.url.blank?
      upload.destroy!
      next
    end

    # no need to download an upload twice
    if local_store.has_been_uploaded?(upload.url)
      putc '.'
      next
    end

    # try to download the upload
    begin
      # keep track of the previous url
      previous_url = upload.url
      # fix the name of pasted images
      upload.original_filename = "blob.png" if upload.original_filename == "blob"
      # download the file (in a temp file)
      temp_file = FileHelper.download("http:" + previous_url, max_file_size, "from_s3")
      # store the file locally
      upload.url = local_store.store_upload(temp_file, upload)
      # save the new url
      if upload.save
        # update & rebake the posts (if any)
        Post.where("raw ILIKE ?", "%#{previous_url}%").find_each do |post|
          post.raw = post.raw.gsub(previous_url, upload.url)
          post.save
        end

        putc '#'
      else
        putc 'X'
      end

      # close the temp_file
      temp_file.close! if temp_file.respond_to? :close!
    rescue
      putc 'X'
    end

  end

  puts

end

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
    Upload.order(:id).find_each do |upload|
      path = "#{public_directory}#{upload.url}"
      if !File.exists?(path)
        upload.destroy rescue nil
        putc "#"
      else
        putc "."
      end
    end

    # optimized images
    OptimizedImage.order(:id).find_each do |optimized_image|
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


# list all missing uploads and optimized images
task "uploads:missing" => :environment do

  public_directory = "#{Rails.root}/public"

  RailsMultisite::ConnectionManagement.each_connection do |db|

    if Discourse.store.external?
      puts "This task only works for internal storages."
      next
    end


    Upload.order(:id).find_each do |upload|

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

    OptimizedImage.order(:id).find_each do |optimized_image|

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
