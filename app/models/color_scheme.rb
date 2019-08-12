# frozen_string_literal: true

require_dependency 'distributed_cache'

class ColorScheme < ActiveRecord::Base

  # rubocop:disable Layout/AlignHash

  CUSTOM_SCHEMES = {
    'Dark': {
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
    },
    # By @itsbhanusharma
    'Neutral': {
      "primary" =>           '000000',
      "secondary" =>         'ffffff',
      "tertiary" =>          '51839b',
      "quaternary" =>        'b85e48',
      "header_background" => '333333',
      "header_primary" =>    'f3f3f3',
      "highlight" =>         'ecec70',
      "danger" =>            'b85e48',
      "success" =>           '518751',
      "love" =>              'fa6c8d'
    },
    # By @Flower_Child
    'Grey Amber': {
      "primary" =>           'd9d9d9',
      "secondary" =>         '3d4147',
      "tertiary" =>          'fdd459',
      "quaternary" =>        'fdd459',
      "header_background" => '36393e',
      "header_primary" =>    'd9d9d9',
      "highlight" =>         'fdd459',
      "danger" =>            'e45735',
      "success" =>           'fdd459',
      "love" =>              'fdd459'
    },
    # By @rafafotes
    'Shades of Blue': {
      "primary" =>           '203243',
      "secondary" =>         'eef4f7',
      "tertiary" =>          '416376',
      "quaternary" =>        '5e99b9',
      "header_background" => '86bddb',
      "header_primary" =>    'ffffff',
      "highlight" =>         '86bddb',
      "danger" =>            'bf3c3c',
      "success" =>           '70db82',
      "love" =>              'fc94cb'
    },
    # By @mikechristopher
    'Latte': {
      "primary" =>           'f2e5d7',
      "secondary" =>         '262322',
      "tertiary" =>          'f7f2ed',
      "quaternary" =>        'd7c9aa',
      "header_background" => 'd7c9aa',
      "header_primary" =>    '262322',
      "highlight" =>         'd7c9aa',
      "danger" =>            'db9584',
      "success" =>           '78be78',
      "love" =>              '8f6201'
    },
    # By @Flower_Child
    'Summer': {
      "primary" =>           '874342',
      "secondary" =>         'fffff4',
      "tertiary" =>          'fe9896',
      "quaternary" =>        'fcc9d0',
      "header_background" => '96ccbf',
      "header_primary" =>    'fff1e7',
      "highlight" =>         'f3c07f',
      "danger" =>            'cfebdc',
      "success" =>           'fcb4b5',
      "love" =>              'f3c07f'
    },
    # By @Flower_Child
    'Dark Rose': {
      "primary" =>           'ca9cb2',
      "secondary" =>         '3a2a37',
      "tertiary" =>          'fdd459',
      "quaternary" =>        '7e566a',
      "header_background" => 'a97189',
      "header_primary" =>    'd9b2bb',
      "highlight" =>         '6c3e63',
      "danger" =>            '6c3e63',
      "success" =>           'd9b2bb',
      "love" =>              'd9b2bb'
    }
  }

  # rubocop:enable Layout/AlignHash

  LIGHT_THEME_ID = 'Light'

  def self.base_color_scheme_colors
    base_with_hash = {}

    base_colors.each do |name, color|
      base_with_hash[name] = "#{color}"
    end

    list = [
      { id: LIGHT_THEME_ID, colors: base_with_hash }
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
  COLOR_TRANSFORMATION_FILE = "#{Rails.root}/app/assets/stylesheets/common/foundation/color_transformations.scss"

  @mutex = Mutex.new

  def self.base_colors
    return @base_colors if @base_colors
    @mutex.synchronize do
      return @base_colors if @base_colors
      base_colors = {}
      File.readlines(BASE_COLORS_FILE).each do |line|
        matches = /\$([\w]+):\s*#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})(?:[;]|\s)/.match(line.strip)
        base_colors[matches[1]] = matches[2] if matches
      end
      @base_colors = base_colors
    end
    @base_colors
  end

  def self.color_transformation_variables
    return @transformation_variables if @transformation_variables
    @mutex.synchronize do
      return @transformation_variables if @transformation_variables
      transformation_variables = []
      File.readlines(COLOR_TRANSFORMATION_FILE).each do |line|
        matches = /\$([\w\-_]+):.*/.match(line.strip)
        transformation_variables.append(matches[1]) if matches
      end
      @transformation_variables = transformation_variables
    end
    @transformation_variables
  end

  def self.base_color_schemes
    base_color_scheme_colors.map do |hash|
      scheme = new(name: I18n.t("color_schemes.#{hash[:id].downcase.gsub(' ', '_')}"), base_scheme_id: hash[:id])
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

  def self.lookup_hex_for_name(name, scheme_id = nil)
    enabled_color_scheme = find_by(id: scheme_id) if scheme_id
    enabled_color_scheme ||= Theme.where(id: SiteSetting.default_theme_id).first&.color_scheme
    (enabled_color_scheme || base).colors.find { |c| c.name == name }.try(:hex) || "nil"
  end

  def self.hex_for_name(name, scheme_id = nil)
    cache_key = scheme_id ? name + "_#{scheme_id}" : name
    hex_cache[cache_key] ||= lookup_hex_for_name(name, scheme_id)
    hex_cache[cache_key] == "nil" ? nil : hex_cache[cache_key]
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
    if base_scheme_id && base_scheme_id != "Light"
      colors = CUSTOM_SCHEMES[base_scheme_id.to_sym]
    end
    colors || ColorScheme.base_colors
  end

  def resolved_colors
    resolved = ColorScheme.base_colors.dup
    if base_scheme_id && base_scheme_id != "Light"
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
      theme_ids = Theme.where(color_scheme_id: self.id).pluck(:id)
      if theme_ids.present?
        Stylesheet::Manager.cache.clear
        Theme.notify_theme_change(
          theme_ids,
          with_scheme: true,
          clear_manager_cache: false,
          all_themes: true
        )
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
