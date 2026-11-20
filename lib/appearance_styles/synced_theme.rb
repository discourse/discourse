# frozen_string_literal: true

# Complete, standalone copies of bundled Horizon, plus a checked style overlay.
# Provenance belongs to the theme so retained versions still receive updates
# after their appearance change is discarded. Components are shared records.
class AppearanceStyles::SyncedTheme
  class SyncError < StandardError
  end

  def self.horizon?(theme)
    theme &&
      (
        theme.id == Theme::CORE_THEMES["horizon"] ||
          (theme.appearance_sync.present? && unchanged?(theme))
      )
  end

  def self.unchanged?(theme)
    metadata = theme.appearance_sync
    metadata.present? && metadata["base_theme_id"] == Theme::CORE_THEMES["horizon"] &&
      metadata["digest"] == digest(theme)
  end

  # Compare source-owned files and local configuration, not bake timestamps,
  # version names or palette selection. All three legitimately change in core.
  def self.digest(theme)
    snapshot = {
      fields:
        theme
          .theme_fields
          .order(:target_id, :name)
          .pluck(:target_id, :name, :type_id, :value, :upload_id),
      settings: theme.theme_settings.order(:name).pluck(:name, :data_type, :value, :json_value),
      site_settings: theme.theme_site_settings.order(:name).pluck(:name, :data_type, :value),
      translations:
        theme
          .theme_translation_overrides
          .order(:locale, :translation_key)
          .pluck(:locale, :translation_key, :value),
      components: theme.child_theme_relation.order(:child_theme_id).pluck(:child_theme_id),
      modifiers:
        theme.theme_modifier_set.attributes.except("id", "theme_id", "created_at", "updated_at"),
      component: theme.component,
    }
    Digest::SHA256.hexdigest(JSON.generate(snapshot))
  end

  def self.create!(theme:, source:, styles:, css:)
    sync!(theme:, styles:, css:)
    theme.reload
    Theme.transaction do
      source.settings.each do |name, setting|
        target = theme.settings[name]
        target.value = setting.value if target && target.type == setting.type
      end
      source.theme_site_settings.each do |setting|
        next if !SiteSetting.themeable[setting.name.to_sym]
        theme
          .theme_site_settings
          .find_or_initialize_by(name: setting.name)
          .tap do |target|
            target.assign_attributes(setting.attributes.slice("value", "data_type"))
            target.save!
          end
      end
      theme.child_theme_ids = source.child_theme_ids
      theme.save!
      record!(theme, styles:, css:)
    end
  end

  # Bundled Horizon's own files, so a copy is only imported again when they
  # change, not every time core syncs its system themes (on every deploy).
  def self.source_digest(source = Theme.horizon_theme)
    Digest::SHA256.hexdigest(
      JSON.generate(
        source
          .theme_fields
          .order(:target_id, :name, :type_id)
          .pluck(:target_id, :name, :type_id, :value, :upload_id),
      ),
    )
  end

  def self.resync!(theme, source_digest: self.source_digest)
    theme.with_lock do
      return false if !unchanged?(theme)
      metadata = theme.appearance_sync
      return true if metadata["source_digest"] == source_digest
      sync!(theme:, styles: metadata.fetch("styles"), css: metadata.fetch("css"))
    end
    true
  end

  def self.sync!(theme:, styles:, css:)
    result = AppearanceStyles::Policy.call(styles, base_theme_id: Theme::CORE_THEMES["horizon"])
    raise SyncError, result.errors.join("\n") if !result.valid? || result.css != css

    Theme.transaction(requires_new: true) do
      # The importer deliberately preserves existing names and selected palettes.
      # It also runs Horizon's setting migrations, including removed settings.
      site_settings =
        theme.theme_site_settings.map { |s| s.attributes.slice("name", "value", "data_type") }
      copy =
        RemoteTheme.import_theme_from_directory(
          Rails.root.join("themes/horizon").to_s,
          theme_id: theme.id,
          allow_out_of_sequence_migration: true,
        )
      site_settings.each do |attributes|
        copy
          .theme_site_settings
          .find_or_initialize_by(name: attributes.fetch("name"))
          .update!(attributes)
      end
      field = copy.theme_fields.find_by(target_id: Theme.targets[:common], name: "scss")
      copy.set_field(target: :common, name: :scss, value: "#{field&.value}\n#{css}")
      copy.save!
      copy.theme_fields.each do |theme_field|
        raise SyncError, theme_field.error if theme_field.error.present?
      end
      # The palettes belong to the appearance change, not this directory import.
      # Do not accumulate a separate set of bundled palettes for every version.
      copy
        .color_schemes
        .where.not(id: [copy.color_scheme_id, copy.dark_color_scheme_id])
        .destroy_all
      record!(copy, styles:, css:)
    end
    theme.reload
  end

  def self.record!(theme, styles:, css:)
    theme.update!(
      appearance_sync: {
        "base_theme_id" => Theme::CORE_THEMES["horizon"],
        "styles" => styles.deep_stringify_keys,
        "css" => css,
        "digest" => digest(theme),
        "source_digest" => source_digest,
      },
    )
  end
end
