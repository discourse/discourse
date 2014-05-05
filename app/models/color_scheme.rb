class ColorScheme < ActiveRecord::Base

  has_many :color_scheme_colors, -> { order('id ASC') }, dependent: :destroy

  alias_method :colors, :color_scheme_colors

  scope :current_version, ->{ where(versioned_id: nil) }

  after_destroy :destroy_versions

  def self.enabled
    current_version.where(enabled: true).first || find(1)
  end

  def can_edit?
    self.id != 1 # base theme shouldn't be edited, except by seed data
  end

  def colors=(arr)
    @colors_by_name = nil
    arr.each do |c|
      self.color_scheme_colors << ColorSchemeColor.new(
        name: c[:name],
        hex: c[:hex],
        opacity: c[:opacity].to_i
      )
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
      {name: c.name, hex: c.hex, opacity: c.opacity}
    end
  end

  def previous_version
    ColorScheme.where(versioned_id: self.id).where('version < ?', self.version).order('version DESC').first
  end

  def destroy_versions
    ColorScheme.where(versioned_id: self.id).destroy_all
  end

end
