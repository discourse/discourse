# frozen_string_literal: true

class RemoteTheme < ActiveRecord::Base
  METADATA_PROPERTIES = %i[
    license_url
    about_url
    authors
    theme_version
    minimum_discourse_version
    maximum_discourse_version
  ]

  class ImportError < StandardError
  end

  ALLOWED_FIELDS = %w[
    scss
    embedded_scss
    embedded_header
    head_tag
    header
    after_header
    body_tag
    footer
  ]

  GITHUB_REGEXP = %r{\Ahttps?://github\.com/}
  GITHUB_SSH_REGEXP = %r{\Assh://git@github\.com:}

  MAX_METADATA_FILE_SIZE = Discourse::MAX_METADATA_FILE_SIZE
  MAX_ASSET_FILE_SIZE = 8.megabytes
  MAX_THEME_FILE_COUNT = 1024
  MAX_THEME_SIZE = 256.megabytes
  MAX_THEME_SCREENSHOT_FILE_SIZE = 1.megabyte
  MAX_THEME_SCREENSHOT_DIMENSIONS = [3840, 2160] # 4K resolution
  THEME_SCREENSHOT_ALLOWED_FILE_TYPES = %w[.jpg .jpeg .gif .png].freeze

  has_one :theme, autosave: false
  scope :joined_remotes,
        -> do
          joins("JOIN themes ON themes.remote_theme_id = remote_themes.id").where.not(
            remote_url: "",
          )
        end

  validates_format_of :minimum_discourse_version,
                      :maximum_discourse_version,
                      with: Discourse::VERSION_REGEXP,
                      allow_nil: true

  def self.extract_theme_info(importer)
    if importer.file_size("about.json") > MAX_METADATA_FILE_SIZE
      raise ImportError.new I18n.t(
                              "themes.import_error.about_json_too_big",
                              limit:
                                ActiveSupport::NumberHelper.number_to_human_size(
                                  MAX_METADATA_FILE_SIZE,
                                ),
                            )
    end

    begin
      json = JSON.parse(importer["about.json"])
      json.fetch("name")
      json
    rescue TypeError, JSON::ParserError, KeyError
      raise ImportError.new I18n.t("themes.import_error.about_json")
    end
  end

  def self.update_zipped_theme(
    filename,
    original_filename,
    user: Discourse.system_user,
    theme_id: nil,
    update_components: nil,
    run_migrations: true
  )
    update_theme(
      ThemeStore::ZipImporter.new(filename, original_filename),
      user:,
      theme_id:,
      update_components:,
      run_migrations:,
    )
  end

  # This is only used in the development and test environment and is currently not supported for other environments
  if Rails.env.test? || Rails.env.development?
    def self.import_theme_from_directory(directory)
      update_theme(ThemeStore::DirectoryImporter.new(directory), update_components: "none")
    end
  end

  def self.update_theme(
    importer,
    user: Discourse.system_user,
    theme_id: nil,
    update_components: nil,
    run_migrations: true
  )
    importer.import!

    theme_info = RemoteTheme.extract_theme_info(importer)
    theme = Theme.find_by(id: theme_id) if theme_id # New theme CLI method

    existing = true
    if theme.blank?
      theme = Theme.new(user_id: user&.id || -1, name: theme_info["name"], auto_update: false)
      existing = false
    end

    theme.component = theme_info["component"].to_s == "true"
    theme.child_components = child_components = theme_info["components"].presence || []
    theme.skip_child_components_update = true if update_components == "none"

    remote_theme = new
    remote_theme.theme = theme
    remote_theme.remote_url = ""

    do_update_child_components = false

    theme.transaction do
      remote_theme.update_from_remote(
        importer,
        skip_update: true,
        already_in_transaction: true,
        run_migrations:,
      )

      if existing && update_components.present? && update_components != "none"
        child_components = child_components.map { |url| ThemeStore::GitImporter.new(url.strip).url }

        if update_components == "sync"
          ChildTheme
            .joins(child_theme: :remote_theme)
            .where("remote_themes.remote_url NOT IN (?)", child_components)
            .delete_all
        end

        child_components -=
          theme
            .child_themes
            .joins(:remote_theme)
            .where("remote_themes.remote_url IN (?)", child_components)
            .pluck("remote_themes.remote_url")
        theme.child_components = child_components
        do_update_child_components = true
      end
    end

    theme.update_child_components if do_update_child_components
    theme
  ensure
    begin
      importer.cleanup!
    rescue => e
      Rails.logger.warn("Failed cleanup remote path #{e}")
    end
  end
  private_class_method :update_theme

  def self.import_theme(url, user = Discourse.system_user, private_key: nil, branch: nil)
    importer = ThemeStore::GitImporter.new(url.strip, private_key: private_key, branch: branch)
    importer.import!

    theme_info = RemoteTheme.extract_theme_info(importer)

    component = [true, "true"].include?(theme_info["component"])
    theme = Theme.new(user_id: user&.id || -1, name: theme_info["name"], component: component)
    theme.child_components = theme_info["components"].presence || []

    remote_theme = new
    theme.remote_theme = remote_theme

    remote_theme.private_key = private_key
    remote_theme.branch = branch
    remote_theme.remote_url = importer.url

    remote_theme.update_from_remote(importer)

    theme
  ensure
    begin
      importer.cleanup!
    rescue => e
      Rails.logger.warn("Failed cleanup remote git #{e}")
    end
  end

  def self.out_of_date_themes
    self
      .joined_remotes
      .where("commits_behind > 0 OR remote_version <> local_version")
      .where(themes: { enabled: true })
      .pluck("themes.name", "themes.id")
  end

  def self.unreachable_themes
    self.joined_remotes.where("last_error_text IS NOT NULL").pluck("themes.name", "themes.id")
  end

  def out_of_date?
    commits_behind > 0 || remote_version != local_version
  end

  def update_remote_version
    return unless is_git?
    importer = ThemeStore::GitImporter.new(remote_url, private_key: private_key, branch: branch)
    begin
      importer.import!
    rescue RemoteTheme::ImportError => err
      self.last_error_text = err.message
    else
      self.updated_at = Time.zone.now
      self.remote_version, self.commits_behind = importer.commits_since(local_version)
      self.last_error_text = nil
    ensure
      self.save!
      begin
        importer.cleanup!
      rescue => e
        Rails.logger.warn("Failed cleanup remote git #{e}")
      end
    end
  end

  def update_from_remote(
    importer = nil,
    skip_update: false,
    raise_if_theme_save_fails: true,
    already_in_transaction: false,
    run_migrations: true
  )
    cleanup = false

    unless importer
      cleanup = true
      importer = ThemeStore::GitImporter.new(remote_url, private_key: private_key, branch: branch)
      begin
        importer.import!
      rescue RemoteTheme::ImportError => err
        self.last_error_text = err.message
        self.save!
        return self
      else
        self.last_error_text = nil
      end
    end

    theme_info = RemoteTheme.extract_theme_info(importer)
    updated_fields = []

    theme_info["assets"]&.each do |name, relative_path|
      if path = importer.real_path(relative_path)
        upload = create_upload(path, relative_path)
        if !upload.errors.empty?
          raise ImportError,
                I18n.t(
                  "themes.import_error.upload",
                  name: name,
                  errors: upload.errors.full_messages.join(","),
                )
        end

        updated_fields << theme.set_field(
          target: :common,
          name: name,
          type: :theme_upload_var,
          upload_id: upload.id,
        )
      end
    end

    # TODO (martin): Until we are ready to roll this out more
    # widely, let's avoid doing this work for most sites.
    if SiteSetting.theme_download_screenshots
      theme_info["screenshots"] = Array.wrap(theme_info["screenshots"]).take(2)
      theme_info["screenshots"].each_with_index do |relative_path, idx|
        if path = importer.real_path(relative_path)
          if !THEME_SCREENSHOT_ALLOWED_FILE_TYPES.include?(File.extname(path))
            raise ImportError,
                  I18n.t(
                    "themes.import_error.screenshot_invalid_type",
                    file_name: File.basename(path),
                    accepted_formats: THEME_SCREENSHOT_ALLOWED_FILE_TYPES.join(","),
                  )
          end

          if File.size(path) > MAX_THEME_SCREENSHOT_FILE_SIZE
            raise ImportError,
                  I18n.t(
                    "themes.import_error.screenshot_invalid_size",
                    file_name: File.basename(path),
                    max_size:
                      ActiveSupport::NumberHelper.number_to_human_size(
                        MAX_THEME_SCREENSHOT_FILE_SIZE,
                      ),
                  )
          end

          screenshot_width, screenshot_height = FastImage.size(path)
          if (screenshot_width.nil? || screenshot_height.nil?) ||
               screenshot_width > MAX_THEME_SCREENSHOT_DIMENSIONS[0] ||
               screenshot_height > MAX_THEME_SCREENSHOT_DIMENSIONS[1]
            raise ImportError,
                  I18n.t(
                    "themes.import_error.screenshot_invalid_dimensions",
                    file_name: File.basename(path),
                    width: screenshot_width.to_i,
                    height: screenshot_height.to_i,
                    max_width: MAX_THEME_SCREENSHOT_DIMENSIONS[0],
                    max_height: MAX_THEME_SCREENSHOT_DIMENSIONS[1],
                  )
          end

          upload = create_upload(path, relative_path)
          if !upload.errors.empty?
            raise ImportError,
                  I18n.t(
                    "themes.import_error.screenshot",
                    errors: upload.errors.full_messages.join(","),
                  )
          end

          updated_fields << theme.set_field(
            target: :common,
            name: "screenshot_#{idx + 1}",
            type: :theme_screenshot_upload_var,
            upload_id: upload.id,
          )
        end
      end
    end

    # Update all theme attributes if this is just a placeholder
    if self.remote_url.present? && !self.local_version && !self.commits_behind
      self.theme.name = theme_info["name"]
      self.theme.component = [true, "true"].include?(theme_info["component"])
      self.theme.child_components = theme_info["components"].presence || []
    end

    METADATA_PROPERTIES.each do |property|
      self.public_send(:"#{property}=", theme_info[property.to_s])
    end

    if !self.valid?
      raise ImportError,
            I18n.t(
              "themes.import_error.about_json_values",
              errors: self.errors.full_messages.join(","),
            )
    end

    ThemeModifierSet.modifiers.keys.each do |modifier_name|
      value = theme_info.dig("modifiers", modifier_name.to_s)
      if Hash === value && value["type"] == "setting"
        theme.theme_modifier_set.add_theme_setting_modifier(modifier_name, value["value"])
      else
        theme.theme_modifier_set.public_send(:"#{modifier_name}=", value)
      end
    end

    if !theme.theme_modifier_set.valid?
      raise ImportError,
            I18n.t(
              "themes.import_error.modifier_values",
              errors: theme.theme_modifier_set.errors.full_messages.join(","),
            )
    end

    all_files = importer.all_files

    if all_files.size > MAX_THEME_FILE_COUNT
      raise ImportError,
            I18n.t(
              "themes.import_error.too_many_files",
              count: all_files.size,
              limit: MAX_THEME_FILE_COUNT,
            )
    end

    theme_size = 0

    all_files.each do |filename|
      next unless opts = ThemeField.opts_from_file_path(filename)

      file_size = importer.file_size(filename)

      if file_size > MAX_ASSET_FILE_SIZE
        raise ImportError,
              I18n.t(
                "themes.import_error.asset_too_big",
                filename: filename,
                limit: ActiveSupport::NumberHelper.number_to_human_size(MAX_ASSET_FILE_SIZE),
              )
      end

      theme_size += file_size

      if theme_size > MAX_THEME_SIZE
        raise ImportError,
              I18n.t(
                "themes.import_error.theme_too_big",
                limit: ActiveSupport::NumberHelper.number_to_human_size(MAX_THEME_SIZE),
              )
      end

      value = importer[filename]
      updated_fields << theme.set_field(**opts.merge(value: value))
    end

    if !skip_update
      self.remote_updated_at = Time.zone.now
      self.remote_version = importer.version
      self.local_version = importer.version
      self.commits_behind = 0
    end

    transaction_block = ->(*) do
      # Destroy fields that no longer exist in the remote theme
      field_ids_to_destroy = theme.theme_fields.pluck(:id) - updated_fields.map { |tf| tf&.id }
      ThemeField.where(id: field_ids_to_destroy).destroy_all

      update_theme_color_schemes(theme, theme_info["color_schemes"]) unless theme.component

      self.save!

      if raise_if_theme_save_fails
        theme.save!
      else
        raise ActiveRecord::Rollback if !theme.save
      end

      theme.migrate_settings(start_transaction: false) if run_migrations
    end

    if already_in_transaction
      transaction_block.call
    else
      self.transaction(&transaction_block)
    end

    theme.theme_modifier_set.save! if theme.theme_modifier_set.refresh_theme_setting_modifiers

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
    override = nil if override !~ /\A[0-9a-f]{6}\z/
    override
  end

  def update_theme_color_schemes(theme, schemes)
    missing_scheme_names = Hash[*theme.color_schemes.pluck(:name, :id).flatten]
    ordered_schemes = []

    schemes&.each do |name, colors|
      missing_scheme_names.delete(name)
      scheme = theme.color_schemes.find_by(name: name) || theme.color_schemes.build(name: name)

      # Update main colors
      ColorScheme.base.colors_hashes.each do |color|
        override = normalize_override(colors[color[:name]])
        color_scheme_color =
          scheme.color_scheme_colors.to_a.find { |c| c.name == color[:name] } ||
            scheme.color_scheme_colors.build(name: color[:name])
        color_scheme_color.hex = override || color[:hex]
        theme.notify_color_change(color_scheme_color) if color_scheme_color.hex_changed?
      end

      # Update advanced colors
      ColorScheme.color_transformation_variables.each do |variable_name|
        override = normalize_override(colors[variable_name])
        color_scheme_color = scheme.color_scheme_colors.to_a.find { |c| c.name == variable_name }
        if override
          color_scheme_color ||= scheme.color_scheme_colors.build(name: variable_name)
          color_scheme_color.hex = override
          theme.notify_color_change(color_scheme_color) if color_scheme_color.hex_changed?
        elsif color_scheme_color # No longer specified in about.json, delete record
          scheme.color_scheme_colors.delete(color_scheme_color)
          theme.notify_color_change(nil, scheme: scheme)
        end
      end

      ordered_schemes << scheme
    end

    if missing_scheme_names.length > 0
      ColorScheme.where(id: missing_scheme_names.values).delete_all
      # we may have stuff pointed at the incorrect scheme?
    end

    theme.color_scheme = ordered_schemes.first if theme.new_record?
  end

  def github_diff_link
    if github_repo_url.present? && local_version != remote_version
      "#{github_repo_url.gsub(/\.git\z/, "")}/compare/#{local_version}...#{remote_version}"
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

  def is_git?
    remote_url.present?
  end

  def create_upload(path, relative_path)
    new_path = "#{File.dirname(path)}/#{SecureRandom.hex}#{File.extname(path)}"

    # OptimizedImage has strict file name restrictions, so rename temporarily
    File.rename(path, new_path)

    UploadCreator.new(
      File.open(new_path),
      File.basename(relative_path),
      for_theme: true,
    ).create_for(theme.user_id)
  end
end

# == Schema Information
#
# Table name: remote_themes
#
#  id                        :integer          not null, primary key
#  remote_url                :string           not null
#  remote_version            :string
#  local_version             :string
#  about_url                 :string
#  license_url               :string
#  commits_behind            :integer
#  remote_updated_at         :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  private_key               :text
#  branch                    :string
#  last_error_text           :text
#  authors                   :string
#  theme_version             :string
#  minimum_discourse_version :string
#  maximum_discourse_version :string
#
