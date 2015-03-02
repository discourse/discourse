require "digest/sha1"

class OptimizedImage < ActiveRecord::Base
  belongs_to :upload

  def self.create_for(upload, width, height, opts={})
    return unless width > 0 && height > 0

    # do we already have that thumbnail?
    thumbnail = find_by(upload_id: upload.id, width: width, height: height)

    # make sure the previous thumbnail has not failed
    if thumbnail && thumbnail.url.blank?
      thumbnail.destroy
      thumbnail = nil
    end

    # return the previous thumbnail if any
    return thumbnail unless thumbnail.nil?

    # create the thumbnail otherwise
    external_copy = Discourse.store.download(upload) if Discourse.store.external?
    original_path = if Discourse.store.external?
      external_copy.try(:path)
    else
      Discourse.store.path_for(upload)
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
      else
        resized = resize(original_path, temp_path, width, height, opts)
      end

      if resized
        thumbnail = OptimizedImage.create!(
          upload_id: upload.id,
          sha1: Digest::SHA1.file(temp_path).hexdigest,
          extension: extension,
          width: width,
          height: height,
          url: "",
        )
        # store the optimized image and update its url
        url = Discourse.store.store_optimized_image(temp_file, thumbnail)
        if url.present?
          thumbnail.url = url
          thumbnail.save
        else
          Rails.logger.error("Failed to store avatar #{size} for #{upload.url} from #{source}")
        end
      else
        Rails.logger.error("Failed to create optimized image #{width}x#{height} for #{upload.url}")
      end

      # close && remove temp file
      temp_file.close!
    end

    # make sure we remove the cached copy from external stores
    if Discourse.store.external?
      external_copy.try(:close!) rescue nil
    end

    thumbnail
  end

  def destroy
    OptimizedImage.transaction do
      Discourse.store.remove_optimized_image(self)
      super
    end
  end

  def self.resize_instructions(from, to, dimensions, opts={})
    # NOTE: ORDER is important!
    %W{
      #{from}[0]
      -gravity center
      -background transparent
      -thumbnail #{dimensions}^
      -extent #{dimensions}
      -interpolate bicubic
      -unsharp 2x0.5+0.7+0
      -quality 98
      #{to}
    }
  end

  def self.resize_instructions_animated(from, to, dimensions, opts={})
    %W{
      #{from}
      -coalesce
      -gravity center
      -thumbnail #{dimensions}^
      -extent #{dimensions}
      #{to}
    }
  end

  def self.downsize_instructions(from, to, dimensions, opts={})
    %W{
      #{from}[0]
      -gravity center
      -background transparent
      -thumbnail #{dimensions}#{!!opts[:force_aspect_ratio] ? "\\!" : "\\>"}
      #{to}
    }
  end

  def self.downsize_instructions_animated(from, to, dimensions, opts={})
    %W{
      #{from}
      -coalesce
      -gravity center
      -background transparent
      -thumbnail #{dimensions}#{!!opts[:force_aspect_ratio] ? "\\!" : "\\>"}
      #{to}
    }
  end

  def self.resize(from, to, width, height, opts={})
    optimize("resize", from, to, width, height, opts)
  end

  def self.downsize(from, to, max_width, max_height, opts={})
    optimize("downsize", from, to, max_width, max_height, opts)
  end

  def self.optimize(operation, from, to, width, height, opts={})
    dim = dimensions(width, height)
    method_name = "#{operation}_instructions"
    method_name += "_animated" if !!opts[:allow_animation] && from =~ /\.GIF$/i
    instructions = self.send(method_name.to_sym, from, to, dim, opts)
    convert_with(instructions)
  end

  def self.dimensions(width, height)
    "#{width}x#{height}"
  end

  def self.convert_with(instructions)
    `convert #{instructions.join(" ")}`

    return false if $?.exitstatus != 0

    ImageOptim.new.optimize_image(to) rescue nil
    true
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
#  url       :string(255)      not null
#
# Indexes
#
#  index_optimized_images_on_upload_id                       (upload_id)
#  index_optimized_images_on_upload_id_and_width_and_height  (upload_id,width,height) UNIQUE
#
