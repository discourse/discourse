# frozen_string_literal: true

class SiteSettingsTask
  def self.export_to_hash(include_defaults: false, include_hidden: false)
    site_settings = SiteSetting.all_settings(include_hidden: include_hidden)
    h = {}
    site_settings.each do |site_setting|
      default = site_setting[:default]
      if site_setting[:mandatory_values]
        default = (site_setting[:mandatory_values].split("|") | default.split("|")).join("|")
      end
      next if default == site_setting[:value] if !include_defaults
      h.store(site_setting[:setting].to_s, site_setting[:value])
    end
    h
  end

  def self.import(yml)
    h = SiteSettingsTask.export_to_hash(include_defaults: true, include_hidden: true)
    counts = { updated: 0, not_found: 0, errors: 0 }
    log = []

    site_settings = YAML.safe_load(yml)
    site_settings.each do |site_setting|
      key = site_setting[0]
      val = site_setting[1]
      if h.has_key?(key)
        if val != h[key] #only update if different
          begin
            result = SiteSetting.set_and_log(key, val)
            log << "Changed #{key} FROM: #{result.previous_value} TO: #{result.new_value}"
            counts[:updated] += 1
          rescue => e
            log << "ERROR: #{e.message}"
            counts[:errors] += 1
          end
        end
      else
        log << "NOT FOUND: existing site setting not found for #{key}"
        counts[:not_found] += 1
      end
    end
    [log, counts]
  end

  def self.names
    SiteSetting
      .all_settings(include_hidden: true)
      .map { |site_setting| site_setting[:setting].to_s }
  end

  def self.rg_installed?
    !`which rg`.strip.empty?
  end

  def self.directory_path(directory_name)
    all_the_parent_dir = ENV["ALL_THE_PARENT_DIR"]
    if all_the_parent_dir
      File.expand_path(File.join(all_the_parent_dir, directory_name))
    else
      File.expand_path(File.join(Dir.pwd, "..", directory_name))
    end
  end

  def self.directories_to_check
    %w[all-the-themes all-the-custom-themes all-the-plugins all-the-custom-plugins]
  end

  def self.directories
    directories = [Dir.pwd]
    SiteSettingsTask.directories_to_check.each do |d|
      if Dir.exist? SiteSettingsTask.directory_path(d)
        directories << SiteSettingsTask.directory_path(d)
      end
    end
    directories
  end

  def self.rg_search_count(term, directory)
    `rg -l --no-ignore "#{term}" "#{directory}" -g '!config' -g '!db/migrate' | wc -l`.strip.to_i
  end
end
