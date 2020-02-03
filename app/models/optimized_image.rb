# frozen_string_literal: true

class OptimizedImage < ActiveRecord::Base
  include HasUrl
  belongs_to :upload

  # BUMP UP if optimized image algorithm changes
  VERSION = 2
  URL_REGEX ||= /(\/optimized\/\dX[\/\.\w]*\/([a-zA-Z0-9]+)[\.\w]*)/

  def self.lock(upload_id, width, height)
    @hostname ||= `hostname`.strip rescue "unknown"
    # note, the extra lock here ensures we only optimize one image per machine on webs
    # this can very easily lead to runaway CPU so slowing it down is beneficial and it is hijacked
    #
    # we can not afford this blocking in Sidekiq cause it can lead to starvation
    if Sidekiq.server?
      DistributedMutex.synchronize("optimized_image_#{upload_id}_#{width}_#{height}") do
        yield
      end
    else
      DistributedMutex.synchronize("optimized_image_host_#{@hostname}") do
        DistributedMutex.synchronize("optimized_image_#{upload_id}_#{width}_#{height}") do
          yield
        end
      end
    end
  end

  def self.create_for(upload, width, height, opts = {})
    return unless width > 0 && height > 0
    return if upload.try(:sha1).blank?

    # no extension so try to guess it
    if (!upload.extension)
      upload.fix_image_extension
    end

    if !upload.extension.match?(IM_DECODERS) && upload.extension != "svg"
      if !opts[:raise_on_error]
        # nothing to do ... bad extension, not an image
        return
      else
        raise InvalidAccess
      end
    end

    # prefer to look up the thumbnail without grabbing any locks
    thumbnail = find_by(upload_id: upload.id, width: width, height: height)

    # correct bad thumbnail if needed
    if thumbnail && (thumbnail.url.blank? || thumbnail.version != VERSION)
      thumbnail.destroy!
      thumbnail = nil
    end

    return thumbnail if thumbnail

    lock(upload.id, width, height) do
      # may have been generated since we got the lock
      thumbnail = find_by(upload_id: upload.id, width: width, height: height)

      # return the previous thumbnail if any
      return thumbnail if thumbnail

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
        extension = ".#{opts[:format] || upload.extension}"

        if extension.length == 1
          return nil
        end

        temp_file = Tempfile.new(["discourse-thumbnail", extension])
        temp_path = temp_file.path

        if upload.extension == "svg"
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
            filesize: File.size(temp_path),
            version: VERSION
          )

          # store the optimized image and update its url
          File.open(temp_path) do |file|
            url = Discourse.store.store_optimized_image(file, thumbnail, nil, secure: upload.secure?)
            if url.present?
              thumbnail.url = url
              thumbnail.save
            else
              Rails.logger.error("Failed to store optimized image of size #{width}x#{height} from url: #{upload.url}\nTemp image path: #{temp_path}")
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
      Discourse.store.remove_optimized_image(self) if self.upload
      super
    end
  end

  def local?
    !(url =~ /^(https?:)?\/\//)
  end

  def calculate_filesize
    path =
      if local?
        Discourse.store.path_for(self)
      else
        Discourse.store.download(self).path
      end
    File.size(path)
  end

  def filesize
    if size = read_attribute(:filesize)
      size
    else
      # we may have a bad optimized image so just skip for now
      # and do not break here
      size = calculate_filesize rescue nil

      write_attribute(:filesize, size)
      if !new_record?
        update_columns(filesize: size)
      end
      size
    end
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

  IM_DECODERS ||= /\A(jpe?g|png|ico|gif)\z/i

  def self.prepend_decoder!(path, ext_path = nil, opts = nil)
    opts ||= {}

    # This logic is a little messy but the result of using mocks for most
    # of the image tests. The idea here is you shouldn't trust the "original"
    # path of a file to figure out its extension. However, in certain cases
    # such as generating the loading upload thumbnail, we force the format,
    # and this allows us to use the forced format in that case.
    extension = nil
    if (opts[:format] && path != ext_path)
      extension = File.extname(path)[1..-1]
    else
      extension = File.extname(opts[:filename] || ext_path || path)[1..-1]
    end

    raise Discourse::InvalidAccess if !extension || !extension.match?(IM_DECODERS)
    "#{extension}:#{path}"
  end

  def self.thumbnail_or_resize
    SiteSetting.strip_image_metadata ? "thumbnail" : "resize"
  end

  def self.resize_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    # note FROM my not be named correctly
    from = prepend_decoder!(from, to, opts)
    to = prepend_decoder!(to, to, opts)

    instructions = ['convert', "#{from}[0]"]

    if opts[:colors]
      instructions << "-colors" << opts[:colors].to_s
    end

    # NOTE: ORDER is important!
    instructions.concat(%W{
      -auto-orient
      -gravity center
      -background transparent
      -#{thumbnail_or_resize} #{dimensions}^
      -extent #{dimensions}
      -interpolate catrom
      -unsharp 2x0.5+0.7+0
      -interlace none
      -quality 98
      -profile #{File.join(Rails.root, 'vendor', 'data', 'RT_sRGB.icm')}
      #{to}
    })
  end

  def self.resize_instructions_animated(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    %W{
      gifsicle
      --colors=#{opts[:colors] || 256}
      --resize-fit #{dimensions}
      --optimize=3
      --output #{to}
      #{from}
    }
  end

  def self.crop_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    from = prepend_decoder!(from, to, opts)
    to = prepend_decoder!(to, to, opts)

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
      --colors=#{opts[:colors] || 256}
      --optimize=3
      --output #{to}
      #{from}
    }
  end

  def self.downsize_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    from = prepend_decoder!(from, to, opts)
    to = prepend_decoder!(to, to, opts)

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

    if !!opts[:allow_animation] && (from =~ /\.GIF$/i)
      method_name += "_animated"
    end

    instructions = self.public_send(method_name.to_sym, from, to, dimensions, opts)
    convert_with(instructions, to, opts)
  end

  MAX_PNGQUANT_SIZE = 500_000

  def self.convert_with(instructions, to, opts = {})
    Discourse::Utils.execute_command("nice", "-n", "10", *instructions)

    allow_pngquant = to.downcase.ends_with?(".png") && File.size(to) < MAX_PNGQUANT_SIZE
    FileHelper.optimize_image!(to, allow_pngquant: allow_pngquant)
    true
  rescue => e
    if opts[:raise_on_error]
      raise e
    else
      error = +"Failed to optimize image:"

      if e.message =~ /^convert:([^`]+)/
        error << $1
      else
        error << " unknown reason"
      end

      Discourse.warn(error, location: to, error_message: e.message)
      false
    end
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
#  filesize  :integer
#  etag      :string
#  version   :integer
#
# Indexes
#
#  index_optimized_images_on_etag                            (etag)
#  index_optimized_images_on_upload_id                       (upload_id)
#  index_optimized_images_on_upload_id_and_width_and_height  (upload_id,width,height) UNIQUE
#
