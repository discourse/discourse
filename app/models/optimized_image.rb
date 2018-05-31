require_dependency "file_helper"
require_dependency "url_helper"
require_dependency "db_helper"
require_dependency "file_store/local_store"

class OptimizedImage < ActiveRecord::Base
  belongs_to :upload

  # BUMP UP if optimized image algorithm changes
  VERSION = 1

  def self.lock(upload_id, width, height)
    @hostname ||= `hostname`.strip rescue "unknown"
    # note, the extra lock here ensures we only optimize one image per machine
    # this can very easily lead to runaway CPU so slowing it down is beneficial
    DistributedMutex.synchronize("optimized_image_host_#{@hostname}") do
      DistributedMutex.synchronize("optimized_image_#{upload_id}_#{width}_#{height}") do
        yield
      end
    end
  end

  def self.create_for(upload, width, height, opts = {})
    return unless width > 0 && height > 0
    return if upload.try(:sha1).blank?

    lock(upload.id, width, height) do
      # do we already have that thumbnail?
      thumbnail = find_by(upload_id: upload.id, width: width, height: height)

      # make sure we have an url
      if thumbnail && thumbnail.url.blank?
        thumbnail.destroy
        thumbnail = nil
      end

      # return the previous thumbnail if any
      return thumbnail unless thumbnail.nil?

      # create the thumbnail otherwise
      original_path = Discourse.store.path_for(upload)
      if original_path.blank?
        external_copy = Discourse.store.download(upload) rescue nil
        original_path = external_copy.try(:path)
      end

      if original_path.blank?
        Rails.logger.error("Could not find file in the store located at url: #{upload.url}")
      else
        # create a temp file with the same extension as the original
        extension = File.extname(original_path)
        temp_file = Tempfile.new(["discourse-thumbnail", extension])
        temp_path = temp_file.path

        if extension =~ /\.svg$/i
          FileUtils.cp(original_path, temp_path)
          resized = true
        elsif opts[:crop]
          resized = crop(original_path, temp_path, width, height, opts)
        else
          resized = resize(original_path, temp_path, width, height, opts)
        end

        if resized
          thumbnail = OptimizedImage.create!(
            upload_id: upload.id,
            sha1: Upload.generate_digest(temp_path),
            extension: extension,
            width: width,
            height: height,
            url: "",
          )
          # store the optimized image and update its url
          File.open(temp_path) do |file|
            url = Discourse.store.store_optimized_image(file, thumbnail)
            if url.present?
              thumbnail.url = url
              thumbnail.save
            end
          end
        end

        # close && remove temp file
        temp_file.close!
      end

      # make sure we remove the cached copy from external stores
      if Discourse.store.external?
        external_copy&.close
      end

      thumbnail
    end
  end

  def destroy
    OptimizedImage.transaction do
      Discourse.store.remove_optimized_image(self)
      super
    end
  end

  def local?
    !(url =~ /^(https?:)?\/\//)
  end

  def self.safe_path?(path)
    # this matches instructions which call #to_s
    path = path.to_s
    return false if path != File.expand_path(path)
    return false if path !~ /\A[\w\-\.\/]+\z/m
    true
  end

  def self.ensure_safe_paths!(*paths)
    paths.each do |path|
      raise Discourse::InvalidAccess unless safe_path?(path)
    end
  end

  def self.thumbnail_or_resize
    SiteSetting.strip_image_metadata ? "thumbnail" : "resize"
  end

  def self.resize_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    # NOTE: ORDER is important!
    %W{
      convert
      #{from}[0]
      -auto-orient
      -gravity center
      -background transparent
      -#{thumbnail_or_resize} #{dimensions}^
      -extent #{dimensions}
      -interpolate bicubic
      -unsharp 2x0.5+0.7+0
      -interlace none
      -quality 98
      -profile #{File.join(Rails.root, 'vendor', 'data', 'RT_sRGB.icm')}
      #{to}
    }
  end

  def self.resize_instructions_animated(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    %W{
      gifsicle
      --colors=256
      --resize-fit #{dimensions}
      --optimize=3
      --output #{to}
      #{from}
    }
  end

  def self.crop_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    %W{
      convert
      #{from}[0]
      -auto-orient
      -gravity north
      -background transparent
      -#{thumbnail_or_resize} #{opts[:width]}
      -crop #{dimensions}+0+0
      -unsharp 2x0.5+0.7+0
      -interlace none
      -quality 98
      -profile #{File.join(Rails.root, 'vendor', 'data', 'RT_sRGB.icm')}
      #{to}
    }
  end

  def self.crop_instructions_animated(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    %W{
      gifsicle
      --crop 0,0+#{dimensions}
      --colors=256
      --optimize=3
      --output #{to}
      #{from}
    }
  end

  def self.downsize_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    %W{
      convert
      #{from}[0]
      -auto-orient
      -gravity center
      -background transparent
      -interlace none
      -resize #{dimensions}
      -profile #{File.join(Rails.root, 'vendor', 'data', 'RT_sRGB.icm')}
      #{to}
    }
  end

  def self.downsize_instructions_animated(from, to, dimensions, opts = {})
    resize_instructions_animated(from, to, dimensions, opts)
  end

  def self.resize(from, to, width, height, opts = {})
    optimize("resize", from, to, "#{width}x#{height}", opts)
  end

  def self.crop(from, to, width, height, opts = {})
    opts[:width] = width
    optimize("crop", from, to, "#{width}x#{height}", opts)
  end

  def self.downsize(from, to, dimensions, opts = {})
    optimize("downsize", from, to, dimensions, opts)
  end

  def self.optimize(operation, from, to, dimensions, opts = {})
    method_name = "#{operation}_instructions"
    if !!opts[:allow_animation] && (from =~ /\.GIF$/i || opts[:filename] =~ /\.GIF$/i)
      method_name += "_animated"
    end
    instructions = self.send(method_name.to_sym, from, to, dimensions, opts)
    convert_with(instructions, to)
  end

  def self.convert_with(instructions, to)
    begin
      Discourse::Utils.execute_command(*instructions)
    rescue
      return false
    end

    FileHelper.optimize_image!(to)
    true
  rescue
    Rails.logger.error("Could not optimize image: #{to}")
    false
  end

  def self.migrate_to_new_scheme(limit = nil)
    problems = []

    if SiteSetting.migrate_to_new_scheme
      max_file_size_kb = SiteSetting.max_image_size_kb.kilobytes
      local_store = FileStore::LocalStore.new

      scope = OptimizedImage.includes(:upload)
        .where("url NOT LIKE '%/optimized/_X/%'")
        .order(id: :desc)

      scope.limit(limit) if limit

      scope.each do |optimized_image|
        begin
          # keep track of the url
          previous_url = optimized_image.url.dup
          # where is the file currently stored?
          external = previous_url =~ /^\/\//
          # download if external
          if external
            url = SiteSetting.scheme + ":" + previous_url
            file = FileHelper.download(
              url,
              max_file_size: max_file_size_kb,
              tmp_file_name: "discourse",
              follow_redirect: true
            ) rescue nil
            path = file.path
          else
            path = local_store.path_for(optimized_image)
            file = File.open(path)
          end
          # compute SHA if missing
          if optimized_image.sha1.blank?
            optimized_image.sha1 = Upload.generate_digest(path)
          end
          # optimize if image
          FileHelper.optimize_image!(path)
          # store to new location & update the filesize
          File.open(path) do |f|
            optimized_image.url = Discourse.store.store_optimized_image(f, optimized_image)
            optimized_image.save
          end
          # remap the URLs
          DbHelper.remap(UrlHelper.absolute(previous_url), optimized_image.url) unless external
          DbHelper.remap(previous_url, optimized_image.url)
          # remove the old file (when local)
          unless external
            FileUtils.rm(path, force: true)
          end
        rescue => e
          problems << { optimized_image: optimized_image, ex: e }
          # just ditch the optimized image if there was any errors
          optimized_image.destroy
        ensure
          file&.unlink
          file&.close
        end
      end
    end

    problems
  end

end

# == Schema Information
#
# Table name: optimized_images
#
#  id        :integer          not null, primary key
#  sha1      :string(40)       not null
#  extension :string(10)       not null
#  width     :integer          not null
#  height    :integer          not null
#  upload_id :integer          not null
#  url       :string           not null
#
# Indexes
#
#  index_optimized_images_on_upload_id                       (upload_id)
#  index_optimized_images_on_upload_id_and_width_and_height  (upload_id,width,height) UNIQUE
#
