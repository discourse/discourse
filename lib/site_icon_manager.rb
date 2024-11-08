# frozen_string_literal: true

module SiteIconManager
  extend GlobalPath

  @cache = DistributedCache.new("icon_manager")

  SKETCH_LOGO_ID = -6

  ICONS = {
    digest_logo: {
      width: nil,
      height: nil,
      settings: %i[digest_logo logo],
      fallback_to_sketch: false,
      resize_required: false,
    },
    mobile_logo: {
      width: nil,
      height: nil,
      settings: %i[mobile_logo logo],
      fallback_to_sketch: false,
      resize_required: false,
    },
    large_icon: {
      width: nil,
      height: nil,
      settings: %i[large_icon logo_small],
      fallback_to_sketch: true,
      resize_required: false,
    },
    manifest_icon: {
      width: 512,
      height: 512,
      settings: %i[manifest_icon large_icon logo_small],
      fallback_to_sketch: true,
      resize_required: true,
    },
    favicon: {
      width: 32,
      height: 32,
      settings: %i[favicon large_icon logo_small],
      fallback_to_sketch: true,
      resize_required: false,
    },
    apple_touch_icon: {
      width: 180,
      height: 180,
      settings: %i[apple_touch_icon large_icon logo_small],
      fallback_to_sketch: true,
      resize_required: false,
    },
    opengraph_image: {
      width: nil,
      height: nil,
      settings: %i[opengraph_image large_icon logo_small logo],
      fallback_to_sketch: true,
      resize_required: false,
    },
  }.freeze

  WATCHED_SETTINGS = ICONS.keys + %i[logo logo_small]

  def self.clear_cache!
    @cache.clear
  end

  def self.ensure_optimized!
    unless @disabled
      ICONS.each do |name, info|
        icon = resolve_original(info)

        if info[:height] && info[:width]
          OptimizedImage.create_for(icon, info[:width], info[:height])
        end
      end
    end
    @cache.clear
  end

  ICONS.each do |name, info|
    define_singleton_method(name) do
      icon = resolve_original(info)
      if info[:height] && info[:width]
        result = OptimizedImage.find_by(upload: icon, height: info[:height], width: info[:width])
      end
      result = icon if !result && !info[:resize_required]
      result
    end

    define_singleton_method("#{name}_url") do
      get_set_cache("#{name}_url") do
        icon = self.public_send(name)
        icon ? full_cdn_url(icon.url) : ""
      end
    end
  end

  # Used in test mode
  def self.disable
    @disabled = true
  end

  def self.enable
    @disabled = false
  end

  private

  def self.get_set_cache(key, &block)
    @cache.defer_get_set(key, &block)
  end

  def self.resolve_original(info)
    info[:settings].each do |setting_name|
      value = SiteSetting.get(setting_name)
      return value if value
    end
    return Upload.find(SKETCH_LOGO_ID) if info[:fallback_to_sketch]
    nil
  end
end
