class ColorScheme < ActiveRecord::Base

  attr_accessor :is_base

  has_many :color_scheme_colors, -> { order('id ASC') }, dependent: :destroy

  alias_method :colors, :color_scheme_colors

  scope :current_version, ->{ where(versioned_id: nil) }

  after_destroy :destroy_versions

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

  def self.enabled
    current_version.find_by(enabled: true)
  end

  def self.base
    return @base_color if @base_color
    @base_color = new(name: I18n.t('color_schemes.base_theme_name'), enabled: false)
    @base_color.colors = base_colors.map { |name, hex| {name: name, hex: hex} }
    @base_color.is_base = true
    @base_color
  end


  def colors=(arr)
    @colors_by_name = nil
    arr.each do |c|
      self.color_scheme_colors << ColorSchemeColor.new( name: c[:name], hex: c[:hex] )
    end
  end

  def colors_by_name
    @colors_by_name ||= self.colors.inject({}) { |sum,c| sum[c.name] = c; sum; }
  end
  def clear_colors_cache
    @colors_by_name = nil
  end

  def colors_hashes
    color_scheme_colors.map do |c|
      {name: c.name, hex: c.hex}
    end
  end

  def previous_version
    ColorScheme.where(versioned_id: self.id).where('version < ?', self.version).order('version DESC').first
  end

  def destroy_versions
    ColorScheme.where(versioned_id: self.id).destroy_all
  end

end

# == Schema Information
#
# Table name: color_schemes
#
#  id           :integer          not null, primary key
#  name         :string(255)      not null
#  enabled      :boolean          default(FALSE), not null
#  versioned_id :integer
#  version      :integer          default(1), not null
#  created_at   :datetime
#  updated_at   :datetime
#
