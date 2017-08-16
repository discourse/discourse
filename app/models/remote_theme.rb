require_dependency 'git_importer'
require_dependency 'upload_creator'

class RemoteTheme < ActiveRecord::Base

  ALLOWED_FIELDS = %w{scss embedded_scss head_tag header after_header body_tag footer}

  has_one :theme

  def self.import_theme(url, user = Discourse.system_user)
    importer = GitImporter.new(url)
    importer.import!

    theme_info = JSON.parse(importer["about.json"])
    theme = Theme.new(user_id: user&.id || -1, name: theme_info["name"])

    remote_theme = new
    theme.remote_theme = remote_theme

    remote_theme.remote_url = importer.url
    remote_theme.update_from_remote(importer)

    theme.save!
    theme
  ensure
    begin
      importer.cleanup!
    rescue => e
      Rails.logger.warn("Failed cleanup remote git #{e}")
    end
  end

  def update_remote_version
    importer = GitImporter.new(remote_url)
    importer.import!
    self.updated_at = Time.zone.now
    self.remote_version, self.commits_behind = importer.commits_since(remote_version)
  end

  def update_from_remote(importer = nil)
    return unless remote_url
    cleanup = false

    unless importer
      cleanup = true
      importer = GitImporter.new(remote_url)
      importer.import!
    end

    theme_info = JSON.parse(importer["about.json"])

    theme_info["assets"]&.each do |name, relative_path|
      if path = importer.real_path(relative_path)
        upload = UploadCreator.new(File.open(path), File.basename(relative_path), for_theme: true).create_for(theme.user_id)
        theme.set_field(target: :common, name: name, type: :theme_upload_var, upload_id: upload.id)
      end
    end

    theme_info["fields"]&.each do |name, info|
      unless Hash === info
        info = {
          "target" => :common,
          "type" => :theme_var,
          "value" => info
        }
      end

      if info["type"] == "color"
        info["type"] = :theme_color_var
      end

      theme.set_field(target: info["target"] || :common,
                      name: name,
                      value: info["value"],
                      type: info["type"] || :theme_var)
    end

    Theme.targets.keys.each do |target|
      ALLOWED_FIELDS.each do |field|
        lookup =
          if field == "scss"
            "#{target}.scss"
          elsif field == "embedded_scss" && target == :common
            "embedded.scss"
          else
            "#{field}.html"
          end

        value = importer["#{target}/#{lookup}"]
        theme.set_field(target: target.to_sym, name: field, value: value)
      end
    end

    self.license_url ||= theme_info["license_url"]
    self.about_url ||= theme_info["about_url"]
    self.remote_updated_at = Time.zone.now
    self.remote_version = importer.version
    self.local_version = importer.version
    self.commits_behind = 0

    update_theme_color_schemes(theme, theme_info["color_schemes"])

    self
  ensure
    begin
      importer.cleanup! if cleanup
    rescue => e
      Rails.logger.warn("Failed cleanup remote git #{e}")
    end
  end

  def normalize_override(hex)
    return unless hex

    override = hex.downcase
    if override !~ /\A[0-9a-f]{6}\z/
      override = nil
    end
    override
  end

  def update_theme_color_schemes(theme, schemes)
    return if schemes.blank?

    schemes.each do |name, colors|
      existing = theme.color_schemes.find_by(name: name)
      if existing
        existing.colors.each do |c|
          override = normalize_override(colors[c.name])
          if override && c.hex != override
            c.hex = override
            theme.notify_color_change(c)
          end
        end
      else
        scheme = theme.color_schemes.build(name: name)
        ColorScheme.base.colors_hashes.each do |color|
          override = normalize_override(colors[color[:name]])
          scheme.color_scheme_colors << ColorSchemeColor.new(name: color[:name], hex: override || color[:hex])
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: remote_themes
#
#  id                :integer          not null, primary key
#  remote_url        :string           not null
#  remote_version    :string
#  local_version     :string
#  about_url         :string
#  license_url       :string
#  commits_behind    :integer
#  remote_updated_at :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
