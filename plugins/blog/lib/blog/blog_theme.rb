# frozen_string_literal: true

module ::Blog
  # Themes are documents in the plugin store. Editors change drafts
  # ("theme:<id>"); readers only ever see a frozen copy ("snapshot:<id>"), the
  # latest of which is also kept as "active".
  class BlogTheme
    STORE = "discourse-blog-themes"
    MAX_THEMES = 30
    MAX_SNAPSHOTS = 20
    MAX_NAME_LENGTH = 100
    MAX_CODE_BYTES = 65_536
    COLOR_FIELDS = %w[accent_color paper_color ink_color].freeze
    CODE_FIELDS = %w[css javascript].freeze
    TEMPLATE_FIELDS = TemplateRenderer::PAGES.map { |page| "template_#{page}" }.freeze
    FIELDS = (%w[name] + COLOR_FIELDS + CODE_FIELDS + TEMPLATE_FIELDS).freeze

    # Readers fall back to this until a theme is activated.
    BUILT_IN_PALETTE = {
      "accent_color" => "d64b2a",
      "paper_color" => "f5f0e6",
      "ink_color" => "19382d",
    }.freeze

    def self.defaults
      {
        "name" => I18n.t("blog.themes.current"),
        **BUILT_IN_PALETTE,
        "css" => "",
        "javascript" => "",
      }.merge(TEMPLATE_FIELDS.to_h { |field| [field, ""] })
    end

    def self.all
      drafts.order(:id).map { |row| PluginStore.cast_value(row.type_name, row.value) }
    end

    def self.count
      drafts.count
    end

    def self.find_by(id:)
      PluginStore.get(STORE, draft_key(id))
    end

    def self.find(id)
      find_by(id:) || raise(Discourse::NotFound)
    end

    # The row lock serialises concurrent changes to one draft until the
    # surrounding transaction ends.
    def self.find_and_lock(id)
      row = drafts.lock.find_by(key: draft_key(id))
      PluginStore.cast_value(row.type_name, row.value) if row
    end

    def self.active
      PluginStore.get(STORE, "active") || defaults
    end

    def self.active?(theme)
      active["id"] == theme["id"]
    end

    def self.snapshot(id)
      PluginStore.get(STORE, "snapshot:#{id}") || raise(Discourse::NotFound)
    end

    def self.create(values, source:)
      store(
        values.merge(
          "id" => SecureRandom.uuid,
          "revision" => 1,
          "source" => source,
          "locally_modified" => false,
        ),
      )
    end

    # A pull brings a new source; a manual edit keeps the old one and marks the
    # draft as diverged from it.
    def self.revise(theme, values, source:)
      store(
        values.merge(
          "id" => theme["id"],
          "revision" => theme["revision"] + 1,
          "source" => source || theme["source"],
          "locally_modified" => source.nil? && theme["source"].present?,
        ),
      )
    end

    def self.destroy(theme)
      PluginStore.remove(STORE, draft_key(theme["id"]))
    end

    # Readers use a copy, never the mutable draft or its Git source.
    def self.activate(theme)
      snapshot = theme.merge("snapshot" => SecureRandom.uuid)
      PluginStore.set(STORE, "snapshot:#{snapshot["snapshot"]}", snapshot)
      PluginStore.set(STORE, "active", snapshot)
      snapshot
    end

    def self.prune_snapshots
      PluginStoreRow
        .where(plugin_name: STORE)
        .where("key LIKE 'snapshot:%'")
        .order(id: :desc)
        .offset(MAX_SNAPSHOTS)
        .destroy_all
    end

    def self.drafts
      PluginStoreRow.where(plugin_name: STORE).where("key LIKE 'theme:%'")
    end
    private_class_method :drafts

    def self.draft_key(id)
      "theme:#{id}"
    end
    private_class_method :draft_key

    def self.store(theme)
      PluginStore.set(STORE, draft_key(theme["id"]), theme)
      theme
    end
    private_class_method :store
  end
end
