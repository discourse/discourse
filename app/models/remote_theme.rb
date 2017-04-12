require_dependency 'git_importer'

class RemoteTheme < ActiveRecord::Base
  has_one :theme

  def self.import_theme(url, user=Discourse.system_user)
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

  def update_from_remote(importer=nil)
    return unless remote_url
    cleanup = false
    unless importer
      cleanup = true
      importer = GitImporter.new(remote_url)
      importer.import!
    end

    Theme.targets.keys.each do |target|
      Theme::ALLOWED_FIELDS.each do |field|
        lookup =
          if field == "scss"
            "#{target}.scss"
          elsif field == "embedded_scss" && target == :common
            "embedded.scss"
          else
            "#{field}.html"
          end

        value = importer["#{target}/#{lookup}"]
        theme.set_field(target.to_sym, field, value)
      end
    end

    theme_info = JSON.parse(importer["about.json"])
    self.license_url ||= theme_info["license_url"]
    self.about_url ||= theme_info["about_url"]

    self.remote_updated_at = Time.zone.now
    self.remote_version = importer.version
    self.local_version = importer.version
    self.commits_behind = 0

    self
  ensure
    begin
      importer.cleanup! if cleanup
    rescue => e
      Rails.logger.warn("Failed cleanup remote git #{e}")
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
#  created_at        :datetime
#  updated_at        :datetime
#
