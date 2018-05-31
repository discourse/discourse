# frozen_string_literal: true

require_dependency 'distributed_cache'

class ColorScheme < ActiveRecord::Base

  CUSTOM_SCHEMES = {
    dark: {
      "primary" =>           'dddddd',
      "secondary" =>         '222222',
      "tertiary" =>          '0f82af',
      "quaternary" =>        'c14924',
      "header_background" => '111111',
      "header_primary" =>    'dddddd',
      "highlight" =>         'a87137',
      "danger" =>            'e45735',
      "success" =>           '1ca551',
      "love" =>              'fa6c8d'
    }
  }

  def self.base_color_scheme_colors
    base_with_hash = {}
    base_colors.each do |name, color|
      base_with_hash[name] = "#{color}"
    end

    list = [
      { id: 'default', colors: base_with_hash }
    ]

    CUSTOM_SCHEMES.each do |k, v|
      list.push(id: k.to_s, colors: v)
    end
    list
  end

  def self.hex_cache
    @hex_cache ||= DistributedCache.new("scheme_hex_for_name")
  end

  attr_accessor :is_base

  has_many :color_scheme_colors, -> { order('id ASC') }, dependent: :destroy

  alias_method :colors, :color_scheme_colors

  before_save :bump_version
  after_save :publish_discourse_stylesheet
  after_save :dump_hex_cache
  after_destroy :dump_hex_cache
  belongs_to :theme

  validates_associated :color_scheme_colors

  BASE_COLORS_FILE = "#{Rails.root}/app/assets/stylesheets/common/foundation/colors.scss"

  @mutex = Mutex.new

  def self.base_colors
    @mutex.synchronize do
      return @base_colors if @base_colors
      @base_colors = {}
      File.readlines(BASE_COLORS_FILE).each do |line|
        matches = /\$([\w]+):\s*#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})(?:[;]|\s)/.match(line.strip)
        @base_colors[matches[1]] = matches[2] if matches
      end
    end
    @base_colors
  end

  def self.base_color_schemes
    base_color_scheme_colors.map do |hash|
      scheme = new(name: I18n.t("color_schemes.#{hash[:id]}"), base_scheme_id: hash[:id])
      scheme.colors = hash[:colors].map { |k, v| { name: k.to_s, hex: v.sub("#", "") } }
      scheme.is_base = true
      scheme
    end
  end

  def self.base
    return @base_color_scheme if @base_color_scheme
    @base_color_scheme = new(name: I18n.t('color_schemes.base_theme_name'))
    @base_color_scheme.colors = base_colors.map { |name, hex| { name: name, hex: hex } }
    @base_color_scheme.is_base = true
    @base_color_scheme
  end

  # create_from_base will create a new ColorScheme that overrides Discourse's base color scheme with the given colors.
  def self.create_from_base(params)
    new_color_scheme = new(name: params[:name])
    new_color_scheme.via_wizard = true if params[:via_wizard]
    new_color_scheme.base_scheme_id = params[:base_scheme_id]

    colors = CUSTOM_SCHEMES[params[:base_scheme_id].to_sym]&.map do |name, hex|
      { name: name, hex: hex }
    end if params[:base_scheme_id]
    colors ||= base.colors_hashes

    # Override base values
    params[:colors].each do |name, hex|
      c = colors.find { |x| x[:name].to_s == name.to_s }
      c[:hex] = hex
    end if params[:colors]

    new_color_scheme.colors = colors
    new_color_scheme.save
    new_color_scheme
  end

  def self.lookup_hex_for_name(name)
    enabled_color_scheme = Theme.where(key: SiteSetting.default_theme_key).first&.color_scheme
    (enabled_color_scheme || base).colors.find { |c| c.name == name }.try(:hex) || "nil"
  end

  def self.hex_for_name(name)
    hex_cache[name] ||= lookup_hex_for_name(name)
    hex_cache[name] == "nil" ? nil : hex_cache[name]
  end

  def colors=(arr)
    @colors_by_name = nil
    arr.each do |c|
      self.color_scheme_colors << ColorSchemeColor.new(name: c[:name], hex: c[:hex])
    end
  end

  def colors_by_name
    @colors_by_name ||= self.colors.inject({}) { |sum, c| sum[c.name] = c; sum; }
  end
  def clear_colors_cache
    @colors_by_name = nil
  end

  def colors_hashes
    color_scheme_colors.map do |c|
      { name: c.name, hex: c.hex }
    end
  end

  def base_colors
    colors = nil
    if base_scheme_id && base_scheme_id != "default"
      colors = CUSTOM_SCHEMES[base_scheme_id.to_sym]
    end
    colors || ColorScheme.base_colors
  end

  def resolved_colors
    resolved = ColorScheme.base_colors.dup
    if base_scheme_id && base_scheme_id != "default"
      if scheme = CUSTOM_SCHEMES[base_scheme_id.to_sym]
        scheme.each do |name, value|
          resolved[name] = value
        end
      end
    end
    colors.each do |c|
      resolved[c.name] = c.hex
    end
    resolved
  end

  def publish_discourse_stylesheet
    if self.id
      themes = Theme.where(color_scheme_id: self.id).to_a
      if themes.present?
        Stylesheet::Manager.cache.clear
        themes.each do |theme|
          theme.notify_scheme_change(_clear_manager_cache = false)
        end
      end
    end
  end

  def dump_hex_cache
    self.class.hex_cache.clear
  end

  def bump_version
    if self.id
      self.version += 1
    end
  end

end

# == Schema Information
#
# Table name: color_schemes
#
#  id             :integer          not null, primary key
#  name           :string           not null
#  version        :integer          default(1), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  via_wizard     :boolean          default(FALSE), not null
#  base_scheme_id :string
#  theme_id       :integer
#
