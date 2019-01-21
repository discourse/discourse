require_dependency 'theme_store/git_importer'
require_dependency 'theme_store/tgz_importer'
require_dependency 'upload_creator'

class RemoteTheme < ActiveRecord::Base

  ALLOWED_FIELDS = %w{scss embedded_scss head_tag header after_header body_tag footer}

  GITHUB_REGEXP = /^https?:\/\/github\.com\//
  GITHUB_SSH_REGEXP = /^git@github\.com:/

  has_one :theme
  scope :joined_remotes, -> {
    joins("JOIN themes ON themes.remote_theme_id = remote_themes.id").where.not(remote_url: "")
  }

  def self.update_tgz_theme(filename, user: Discourse.system_user)
    importer = ThemeStore::TgzImporter.new(filename)
    importer.import!

    theme_info = JSON.parse(importer["about.json"])

    theme = Theme.find_by(name: theme_info["name"])
    theme ||= Theme.new(user_id: user&.id || -1, name: theme_info["name"])

    remote_theme = new
    remote_theme.theme = theme
    remote_theme.remote_url = ""
    remote_theme.update_from_remote(importer, skip_update: true)

    theme.save!
    theme
  ensure
    begin
      importer.cleanup!
    rescue => e
      Rails.logger.warn("Failed cleanup remote path #{e}")
    end
  end

  def self.import_theme(url, user = Discourse.system_user, private_key: nil, branch: nil)
    importer = ThemeStore::GitImporter.new(url.strip, private_key: private_key, branch: branch)
    importer.import!

    theme_info = JSON.parse(importer["about.json"])
    component = [true, "true"].include?(theme_info["component"])
    theme = Theme.new(user_id: user&.id || -1, name: theme_info["name"], component: component)

    remote_theme = new
    theme.remote_theme = remote_theme

    remote_theme.private_key = private_key
    remote_theme.branch = branch
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

  def self.out_of_date_themes
    self.joined_remotes.where("commits_behind > 0 OR remote_version <> local_version")
      .pluck("themes.name", "themes.id")
  end

  def self.unreachable_themes
    self.joined_remotes.where("last_error_text IS NOT NULL").pluck("themes.name", "themes.id")
  end

  def update_remote_version
    importer = ThemeStore::GitImporter.new(remote_url, private_key: private_key, branch: branch)
    begin
      importer.import!
    rescue ThemeStore::GitImporter::ImportFailed => err
      self.last_error_text = err.message
    else
      self.updated_at = Time.zone.now
      self.remote_version, self.commits_behind = importer.commits_since(local_version)
      self.last_error_text = nil
    end
  end

  def update_from_remote(importer = nil, skip_update: false)
    return unless remote_url
    cleanup = false

    unless importer
      cleanup = true
      importer = ThemeStore::GitImporter.new(remote_url, private_key: private_key, branch: branch)
      begin
        importer.import!
      rescue ThemeStore::GitImporter::ImportFailed => err
        self.last_error_text = err.message
        return self
      else
        self.last_error_text = nil
      end
    end

    theme_info = JSON.parse(importer["about.json"])

    theme_info["assets"]&.each do |name, relative_path|
      if path = importer.real_path(relative_path)
        new_path = "#{File.dirname(path)}/#{SecureRandom.hex}#{File.extname(path)}"
        File.rename(path, new_path) # OptimizedImage has strict file name restrictions, so rename temporarily
        upload = UploadCreator.new(File.open(new_path), File.basename(relative_path), for_theme: true).create_for(theme.user_id)
        theme.set_field(target: :common, name: name, type: :theme_upload_var, upload_id: upload.id)
      end
    end

    Theme.targets.keys.each do |target|
      next if target == :settings || target == :translations
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

    settings_yaml = importer["settings.yaml"] || importer["settings.yml"]
    theme.set_field(target: :settings, name: "yaml", value: settings_yaml)

    I18n.available_locales.each do |locale|
      value = importer["locales/#{locale}.yml"]
      theme.set_field(target: :translations, name: locale, value: value)
    end

    self.license_url = theme_info["license_url"]
    self.about_url = theme_info["about_url"]

    if !skip_update
      self.remote_updated_at = Time.zone.now
      self.remote_version = importer.version
      self.local_version = importer.version
      self.commits_behind = 0
    end

    update_theme_color_schemes(theme, theme_info["color_schemes"]) unless theme.component

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
    missing_scheme_names = Hash[*theme.color_schemes.pluck(:name, :id).flatten]

    schemes&.each do |name, colors|
      missing_scheme_names.delete(name)
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

    if missing_scheme_names.length > 0
      ColorScheme.where(id: missing_scheme_names.values).delete_all
      # we may have stuff pointed at the incorrect scheme?
    end
  end

  def github_diff_link
    if github_repo_url.present? && local_version != remote_version
      "#{github_repo_url.gsub(/\.git$/, "")}/compare/#{local_version}...#{remote_version}"
    end
  end

  def github_repo_url
    url = remote_url.strip
    return url if url.match?(GITHUB_REGEXP)

    if url.match?(GITHUB_SSH_REGEXP)
      org_repo = url.gsub(GITHUB_SSH_REGEXP, "")
      "https://github.com/#{org_repo}"
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
#  private_key       :text
#  branch            :string
#  last_error_text   :text
#
