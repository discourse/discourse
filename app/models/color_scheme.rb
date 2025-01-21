# frozen_string_literal: true

class ColorScheme < ActiveRecord::Base
  BUILT_IN_SCHEMES = {
    Dark: {
      "primary" => "dddddd",
      "secondary" => "222222",
      "tertiary" => "099dd7",
      "quaternary" => "c14924",
      "header_background" => "111111",
      "header_primary" => "dddddd",
      "highlight" => "a87137",
      "selected" => "052e3d",
      "hover" => "313131",
      "danger" => "e45735",
      "success" => "1ca551",
      "love" => "fa6c8d",
    },
    # By @itsbhanusharma
    Neutral: {
      "primary" => "000000",
      "secondary" => "ffffff",
      "tertiary" => "51839b",
      "quaternary" => "b85e48",
      "header_background" => "333333",
      "header_primary" => "f3f3f3",
      "highlight" => "ecec70",
      "selected" => "e6e6e6",
      "hover" => "f0f0f0",
      "danger" => "b85e48",
      "success" => "518751",
      "love" => "fa6c8d",
    },
    # By @Flower_Child
    "Grey Amber": {
      "primary" => "d9d9d9",
      "secondary" => "3d4147",
      "tertiary" => "fdd459",
      "quaternary" => "fdd459",
      "header_background" => "36393e",
      "header_primary" => "d9d9d9",
      "highlight" => "fdd459",
      "selected" => "272727",
      "hover" => "2F2F30",
      "danger" => "e45735",
      "success" => "fdd459",
      "love" => "fdd459",
    },
    # By @rafafotes
    "Shades of Blue": {
      "primary" => "203243",
      "secondary" => "eef4f7",
      "tertiary" => "416376",
      "quaternary" => "5e99b9",
      "header_background" => "86bddb",
      "header_primary" => "203243",
      "highlight" => "86bddb",
      "selected" => "bee0f2",
      "hover" => "d2efff",
      "danger" => "bf3c3c",
      "success" => "70db82",
      "love" => "fc94cb",
    },
    # By @mikechristopher
    Latte: {
      "primary" => "f2e5d7",
      "secondary" => "262322",
      "tertiary" => "f7f2ed",
      "quaternary" => "d7c9aa",
      "header_background" => "d7c9aa",
      "header_primary" => "262322",
      "highlight" => "d7c9aa",
      "selected" => "3e2a14",
      "hover" => "4c3319",
      "danger" => "db9584",
      "success" => "78be78",
      "love" => "8f6201",
    },
    # By @Flower_Child
    Summer: {
      "primary" => "874342",
      "secondary" => "fffff4",
      "tertiary" => "fe9896",
      "quaternary" => "fcc9d0",
      "header_background" => "96ccbf",
      "header_primary" => "fff1e7",
      "highlight" => "f3c07f",
      "selected" => "f5eaea",
      "hover" => "f9f3f3",
      "danger" => "cfebdc",
      "success" => "fcb4b5",
      "love" => "f3c07f",
    },
    # By @Flower_Child
    "Dark Rose": {
      "primary" => "ca9cb2",
      "secondary" => "3a2a37",
      "tertiary" => "fdd459",
      "quaternary" => "7e566a",
      "header_background" => "a97189",
      "header_primary" => "d9b2bb",
      "highlight" => "bd36a3",
      "selected" => "2a1620",
      "hover" => "331b27",
      "danger" => "6c3e63",
      "success" => "d9b2bb",
      "love" => "d9b2bb",
    },
    WCAG: {
      "primary" => "000000",
      "primary-medium" => "696969",
      "primary-low-mid" => "909090",
      "secondary" => "ffffff",
      "tertiary" => "0033CC",
      "quaternary" => "3369FF",
      "header_background" => "ffffff",
      "header_primary" => "000000",
      "highlight" => "ffff00",
      "highlight-high" => "0036E6",
      "highlight-medium" => "e0e9ff",
      "highlight-low" => "e0e9ff",
      "selected" => "E2E9FE",
      "hover" => "F0F4FE",
      "danger" => "BB1122",
      "success" => "3d854d",
      "love" => "9D256B",
    },
    "WCAG Dark": {
      "primary" => "ffffff",
      "primary-medium" => "999999",
      "primary-low-mid" => "888888",
      "secondary" => "0c0c0c",
      "tertiary" => "759AFF",
      "quaternary" => "759AFF",
      "header_background" => "000000",
      "header_primary" => "ffffff",
      "highlight" => "3369FF",
      "selected" => "0d2569",
      "hover" => "002382",
      "danger" => "FF697A",
      "success" => "70B880",
      "love" => "9D256B",
    },
    # By @zenorocha
    Dracula: {
      "primary_very_low" => "373A47",
      "primary_low" => "414350",
      "primary_low_mid" => "8C8D94",
      "primary_medium" => "A3A4AA",
      "primary_high" => "CCCCCF",
      "primary" => "f2f2f2",
      "primary-50" => "3F414E",
      "primary-100" => "535460",
      "primary-200" => "666972",
      "primary-300" => "7A7C84",
      "primary-400" => "8D8F96",
      "primary-500" => "A2A3A9",
      "primary-600" => "B6B7BC",
      "primary-700" => "C7C7C7",
      "primary-800" => "DEDFE0",
      "primary-900" => "F5F5F5",
      "secondary_low" => "CCCCCF",
      "secondary_medium" => "91939A",
      "secondary_high" => "6A6C76",
      "secondary_very_high" => "3D404C",
      "secondary" => "2d303e",
      "tertiary_low" => "4A4463",
      "tertiary_medium" => "6E5D92",
      "tertiary" => "bd93f9",
      "tertiary_high" => "9275C1",
      "quaternary_low" => "6AA8BA",
      "quaternary" => "8be9fd",
      "header_background" => "373A47",
      "header_primary" => "f2f2f2",
      "highlight_low" => "686D55",
      "highlight_medium" => "52592B",
      "highlight_high" => "C0C879",
      "selected" => "4A4463",
      "hover" => "61597f",
      "danger_low" => "957279",
      "danger" => "ff5555",
      "success_low" => "386D50",
      "success_medium" => "44B366",
      "success" => "50fa7b",
      "love_low" => "6C4667",
      "love" => "ff79c6",
    },
    # By @altercation
    "Solarized Light": {
      "primary_very_low" => "F0ECD7",
      "primary_low" => "D6D8C7",
      "primary_low_mid" => "A4AFA5",
      "primary_medium" => "7E918C",
      "primary_high" => "4C6869",
      "primary" => "002B36",
      "primary-50" => "F0EBDA",
      "primary-100" => "DAD8CA",
      "primary-200" => "B2B9B3",
      "primary-300" => "839496",
      "primary-400" => "76898C",
      "primary-500" => "697F83",
      "primary-600" => "627A7E",
      "primary-700" => "556F74",
      "primary-800" => "415F66",
      "primary-900" => "21454E",
      "secondary_low" => "325458",
      "secondary_medium" => "6C8280",
      "secondary_high" => "97A59D",
      "secondary_very_high" => "E8E6D3",
      "secondary" => "FCF6E1",
      "tertiary_low" => "D6E6DE",
      "tertiary_medium" => "7EBFD7",
      "tertiary" => "0088cc",
      "tertiary_high" => "329ED0",
      "quaternary" => "e45735",
      "header_background" => "FCF6E1",
      "header_primary" => "002B36",
      "highlight_low" => "FDF9AD",
      "highlight_medium" => "E3D0A3",
      "highlight" => "F2F481",
      "highlight_high" => "BCAA7F",
      "selected" => "E8E6D3",
      "hover" => "F0EBDA",
      "danger_low" => "F8D9C2",
      "danger" => "e45735",
      "success_low" => "CFE5B9",
      "success_medium" => "4CB544",
      "success" => "009900",
      "love_low" => "FCDDD2",
      "love" => "fa6c8d",
    },
    # By @altercation
    "Solarized Dark": {
      "primary_very_low" => "0D353F",
      "primary_low" => "193F47",
      "primary_low_mid" => "798C88",
      "primary_medium" => "97A59D",
      "primary_high" => "B5BDB1",
      "primary" => "FCF6E1",
      "primary-50" => "21454E",
      "primary-100" => "415F66",
      "primary-200" => "556F74",
      "primary-300" => "627A7E",
      "primary-400" => "697F83",
      "primary-500" => "76898C",
      "primary-600" => "839496",
      "primary-700" => "B2B9B3",
      "primary-800" => "DAD8CA",
      "primary-900" => "F0EBDA",
      "secondary_low" => "B5BDB1",
      "secondary_medium" => "81938D",
      "secondary_high" => "4E6A6B",
      "secondary_very_high" => "143B44",
      "secondary" => "002B36",
      "tertiary_low" => "003E54",
      "tertiary_medium" => "00557A",
      "tertiary" => "1a97d5",
      "tertiary_high" => "006C9F",
      "quaternary_low" => "944835",
      "quaternary" => "e45735",
      "header_background" => "002B36",
      "header_primary" => "FCF6E1",
      "highlight_low" => "4D6B3D",
      "highlight_medium" => "464C33",
      "highlight" => "F2F481",
      "highlight_high" => "BFCA47",
      "selected" => "143B44",
      "hover" => "21454E",
      "danger_low" => "443836",
      "danger_medium" => "944835",
      "danger" => "e45735",
      "success_low" => "004C26",
      "success_medium" => "007313",
      "success" => "009900",
      "love_low" => "4B3F50",
      "love" => "fa6c8d",
    },
  }

  LIGHT_THEME_ID = "Light"

  def self.base_color_scheme_colors
    base_with_hash = []

    base_colors.each { |name, color| base_with_hash << { name: name, hex: "#{color}" } }

    list = [{ id: LIGHT_THEME_ID, colors: base_with_hash }]

    BUILT_IN_SCHEMES.each do |k, v|
      colors = []
      v.each { |name, color| colors << { name: name, hex: "#{color}" } }
      list.push(id: k.to_s, colors: colors)
    end

    list
  end

  def self.hex_cache
    @hex_cache ||= DistributedCache.new("scheme_hex_for_name")
  end

  attr_accessor :is_base
  attr_accessor :skip_publish

  has_many :color_scheme_colors, -> { order("id ASC") }, dependent: :destroy

  alias_method :colors, :color_scheme_colors

  before_save :bump_version
  after_save_commit :publish_discourse_stylesheet, unless: :skip_publish
  after_save_commit :dump_caches
  after_destroy :dump_caches
  belongs_to :theme

  validates_associated :color_scheme_colors

  BASE_COLORS_FILE = "#{Rails.root}/app/assets/stylesheets/common/foundation/colors.scss"
  COLOR_TRANSFORMATION_FILE =
    "#{Rails.root}/app/assets/stylesheets/common/foundation/color_transformations.scss"

  @mutex = Mutex.new

  def self.base_colors
    return @base_colors if @base_colors
    @mutex.synchronize do
      return @base_colors if @base_colors
      base_colors = {}
      File
        .readlines(BASE_COLORS_FILE)
        .each do |line|
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
      File
        .readlines(COLOR_TRANSFORMATION_FILE)
        .each do |line|
          matches = /\$([\w\-_]+):.*/.match(line.strip)
          transformation_variables.append(matches[1]) if matches
        end
      @transformation_variables = transformation_variables
    end
    @transformation_variables
  end

  def self.base_color_schemes
    base_color_scheme_colors.map do |hash|
      scheme =
        new(
          name: I18n.t("color_schemes.#{hash[:id].downcase.gsub(" ", "_")}"),
          base_scheme_id: hash[:id],
        )
      scheme.colors = hash[:colors].map { |k| { name: k[:name], hex: k[:hex] } }
      scheme.is_base = true
      scheme
    end
  end

  def self.base
    return @base_color_scheme if @base_color_scheme
    @base_color_scheme = new(name: I18n.t("color_schemes.base_theme_name"))
    @base_color_scheme.colors = base_colors.map { |name, hex| { name: name, hex: hex } }
    @base_color_scheme.is_base = true
    @base_color_scheme
  end

  def self.is_base?(scheme_name)
    base_color_scheme_colors.map { |c| c[:id] }.include?(scheme_name)
  end

  # create_from_base will create a new ColorScheme that overrides Discourse's base color scheme with the given colors.
  def self.create_from_base(params)
    new_color_scheme = new(name: params[:name])
    new_color_scheme.via_wizard = true if params[:via_wizard]
    new_color_scheme.base_scheme_id = params[:base_scheme_id]
    new_color_scheme.user_selectable = true

    colors =
      BUILT_IN_SCHEMES[params[:base_scheme_id].to_sym]&.map do |name, hex|
        { name: name, hex: hex }
      end if params[:base_scheme_id]
    colors ||= base.colors_hashes

    # Override base values
    params[:colors].each do |name, hex|
      c = colors.find { |x| x[:name].to_s == name.to_s }
      c[:hex] = hex
    end if params[:colors]

    new_color_scheme.colors = colors
    new_color_scheme.skip_publish if params[:skip_publish]
    new_color_scheme.save
    new_color_scheme
  end

  def self.lookup_hex_for_name(name, scheme_id = nil)
    enabled_color_scheme = find_by(id: scheme_id) if scheme_id
    enabled_color_scheme ||= Theme.where(id: SiteSetting.default_theme_id).first&.color_scheme
    (enabled_color_scheme || base).colors.find { |c| c.name == name }.try(:hex)
  end

  def self.hex_for_name(name, scheme_id = nil)
    hex_cache.defer_get_set(scheme_id ? name + "_#{scheme_id}" : name) do
      lookup_hex_for_name(name, scheme_id)
    end
  end

  def colors=(arr)
    @colors_by_name = nil
    arr.each { |c| self.color_scheme_colors << ColorSchemeColor.new(name: c[:name], hex: c[:hex]) }
  end

  def colors_by_name
    @colors_by_name ||=
      self
        .colors
        .inject({}) do |sum, c|
          sum[c.name] = c
          sum
        end
  end

  def clear_colors_cache
    @colors_by_name = nil
  end

  def colors_hashes
    color_scheme_colors.map { |c| { name: c.name, hex: c.hex } }
  end

  def base_colors
    colors = nil
    colors = BUILT_IN_SCHEMES[base_scheme_id.to_sym] if base_scheme_id && base_scheme_id != "Light"
    colors || ColorScheme.base_colors
  end

  def resolved_colors
    from_base = ColorScheme.base_colors
    from_custom_scheme = base_colors
    from_db = colors.map { |c| [c.name, c.hex] }.to_h

    resolved = from_base.merge(from_custom_scheme).except("hover", "selected").merge(from_db)

    # Equivalent to primary-100 in light mode, or primary-low in dark mode
    resolved["hover"] ||= ColorMath.dark_light_diff(
      resolved["primary"],
      resolved["secondary"],
      0.94,
      -0.78,
    )

    # Equivalent to primary-low in light mode, or primary-100 in dark mode
    resolved["selected"] ||= ColorMath.dark_light_diff(
      resolved["primary"],
      resolved["secondary"],
      0.9,
      -0.8,
    )

    resolved
  end

  def publish_discourse_stylesheet
    self.class.publish_discourse_stylesheets!(self.id) if self.id
  end

  def self.publish_discourse_stylesheets!(id = nil)
    Stylesheet::Manager.clear_color_scheme_cache!

    theme_ids = []
    if id
      theme_ids = Theme.where(color_scheme_id: id).pluck(:id)
    else
      theme_ids = Theme.all.pluck(:id)
    end
    if theme_ids.present?
      Stylesheet::Manager.cache.clear

      Theme.notify_theme_change(
        theme_ids,
        with_scheme: true,
        clear_manager_cache: false,
        all_themes: true,
      )
    end
  end

  def dump_caches
    self.class.hex_cache.clear
    ApplicationSerializer.expire_cache_fragment!("user_color_schemes")
  end

  def bump_version
    self.version += 1 if self.id
  end

  def is_dark?
    return if colors.to_a.empty?

    primary_b = ColorMath.brightness(resolved_colors["primary"])
    secondary_b = ColorMath.brightness(resolved_colors["secondary"])

    primary_b > secondary_b
  end

  def is_wcag?
    base_scheme_id&.start_with?("WCAG")
  end
end

# == Schema Information
#
# Table name: color_schemes
#
#  id              :integer          not null, primary key
#  name            :string           not null
#  version         :integer          default(1), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  via_wizard      :boolean          default(FALSE), not null
#  base_scheme_id  :string
#  theme_id        :integer
#  user_selectable :boolean          default(FALSE), not null
#
