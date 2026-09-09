class OptimizedImage
  def self.safe_path?(path)
    # this matches instructions which call #to_s
    path = path.to_s
    return false if path != File.expand_path(path)
    return false if path !~ %r{\A[\w\-\./]+\z}m
    true
  end

  def self.ensure_safe_paths!(*paths)
    paths.each { |path| raise Discourse::InvalidAccess unless safe_path?(path) }
  end

  IM_DECODERS = /\A(jpe?g|png|ico|gif|webp|avif|svg)\z/i

  def self.prepend_decoder!(path, ext_path = nil, opts = nil)
    opts ||= {}

    # This logic is a little messy but the result of using mocks for most
    # of the image tests. The idea here is you shouldn't trust the "original"
    # path of a file to figure out its extension. However, in certain cases
    # such as generating the loading upload thumbnail, we force the format,
    # and this allows us to use the forced format in that case.
    extension = nil
    if opts[:format] && path != ext_path
      extension = File.extname(path)[1..-1]
    else
      extension = File.extname(opts[:filename] || ext_path || path)[1..-1]
    end

    if !extension || !extension.match?(IM_DECODERS)
      raise Discourse::InvalidAccess.new("Unsupported extension: #{extension}")
    end
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

    instructions = ["#{from}[0]"]

    instructions << "-quality" << opts[:quality].to_s if opts[:quality]

    # NOTE: ORDER is important!
    instructions.concat(
      %W[
        -auto-orient
        -gravity
        center
        -background
        transparent
        -#{thumbnail_or_resize}
        #{dimensions}^
        -extent
        #{dimensions}
        -interpolate
        catrom
        -unsharp
        2x0.5+0.7+0
        -interlace
        none
        -profile
        #{Rails.root.join("vendor/data/RT_sRGB.icm")}
        #{to}
      ],
    )
  end

  def self.crop_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    from = prepend_decoder!(from, to, opts)
    to = prepend_decoder!(to, to, opts)

    instructions = %W{
      #{from}[0]
      -auto-orient
      -gravity
      north
      -background
      transparent
      -#{thumbnail_or_resize}
      #{dimensions}^
      -crop
      #{dimensions}+0+0
      -unsharp
      2x0.5+0.7+0
      -interlace
      none
      -profile
      #{Rails.root.join("vendor/data/RT_sRGB.icm")}
    }

    instructions << "-quality" << opts[:quality].to_s if opts[:quality]

    instructions << to
  end

  def self.downsize_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    from = prepend_decoder!(from, to, opts)
    to = prepend_decoder!(to, to, opts)

    %W{
      #{from}[0]
      -auto-orient
      -gravity
      center
      -background
      transparent
      -interlace
      none
      -resize
      #{dimensions}
      -profile
      #{Rails.root.join("vendor/data/RT_sRGB.icm")}
      #{to}
    }
  end

end
