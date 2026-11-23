# frozen_string_literal: true

module ::Blog
  # Themes are documents in the plugin store. Editors change drafts
  # ("theme:<id>"); readers only ever see a frozen copy ("snapshot:<id>"), and
  # each blog keeps the one it shows on its row.
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

    BUILT_IN_PALETTE = {
      "accent_color" => "d64b2a",
      "paper_color" => "f5f0e6",
      "ink_color" => "19382d",
    }.freeze

    def self.defaults
      {
        "name" => I18n.t("blog.themes.default"),
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

    # Readers see the built-in preset until a theme is activated. An active
    # preset is stored by id only and resolved from the shipped files.
    def self.active_for(blog)
      stored = blog.active_theme
      return stored if stored && !stored["preset"]
      (stored && ThemePresets.find(stored["id"])) || ThemePresets.default
    end

    def self.active_anywhere?(theme)
      Instance.cached.any? { |blog| active_for(blog)["id"] == theme["id"] }
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
    def self.activate(theme, blog)
      active = theme["preset"] ? theme.slice("id", "preset") : snapshot_of(theme)
      # Without a default row the fallback blog is unsaved, so create the row.
      record = blog.new_record? ? DefaultBlogMirror.sync! : Instance.find(blog.id)
      record.active_theme = active
      record.save!(validate: false)
      theme["preset"] ? theme : active
    end

    # A blog keeps showing its snapshot however many newer ones other blogs make.
    def self.prune_snapshots
      in_use = Instance.pluck(:active_theme).filter_map { |active| active&.dig("snapshot") }
      oldest =
        PluginStoreRow
          .where(plugin_name: STORE)
          .where("key LIKE 'snapshot:%'")
          .order(id: :desc)
          .offset(MAX_SNAPSHOTS)
      PluginStoreRow
        .where(id: oldest.select(:id))
        .where.not(key: in_use.map { |id| "snapshot:#{id}" })
        .destroy_all
    end

    def self.snapshot_of(theme)
      snapshot = theme.merge("snapshot" => SecureRandom.uuid)
      PluginStore.set(STORE, "snapshot:#{snapshot["snapshot"]}", snapshot)
      snapshot
    end
    private_class_method :snapshot_of

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
