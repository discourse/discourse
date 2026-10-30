# frozen_string_literal: true

module ::Blog
  class BlogTheme
    STORE = "discourse-blog-themes"
    MAX_THEMES = 30
    MAX_CODE_BYTES = 65_536
    TEMPLATE_FIELDS = TemplateRenderer::PAGES.map { |page| "template_#{page}" }.freeze
    FIELDS = (%w[name accent_color paper_color ink_color css javascript] + TEMPLATE_FIELDS).freeze

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
      PluginStoreRow
        .where(plugin_name: STORE)
        .where("key LIKE 'theme:%'")
        .order(:id)
        .map { |row| PluginStore.cast_value(row.type_name, row.value) }
    end

    def self.find(id)
      PluginStore.get(STORE, "theme:#{id}") || raise(Discourse::NotFound)
    end

    def self.active
      PluginStore.get(STORE, "active") || defaults
    end

    def self.snapshot(id)
      PluginStore.get(STORE, "snapshot:#{id}") || raise(Discourse::NotFound)
    end

    def self.save(attributes, user:, id: nil, revision: nil, source: nil)
      values = TEMPLATE_FIELDS.to_h { |field| [field, ""] }.merge(attributes.slice(*FIELDS))
      validate!(values)
      mutate do
        previous = id ? find(id) : nil
        check_revision!(previous, revision) if previous
        if !previous && all.size >= MAX_THEMES
          raise Discourse::InvalidParameters.new(I18n.t("blog.themes.limit"))
        end
        theme =
          values.merge(
            "id" => previous&.fetch("id") || SecureRandom.uuid,
            "revision" => previous ? previous["revision"] + 1 : 1,
            "source" => source || previous&.dig("source"),
            "locally_modified" => source.nil? && previous&.dig("source").present?,
          )
        PluginStore.set(STORE, "theme:#{theme["id"]}", theme)
        audit(user, "save", theme)
        theme
      end
    end

    def self.activate(id, revision:, user:)
      mutate do
        theme = find(id)
        check_revision!(theme, revision)
        # Readers use a copy, never the mutable editor or Git source.
        theme = theme.merge("snapshot" => SecureRandom.uuid)
        PluginStore.set(STORE, "snapshot:#{theme["snapshot"]}", theme)
        PluginStore.set(STORE, "active", theme)
        PluginStoreRow
          .where(plugin_name: STORE)
          .where("key LIKE 'snapshot:%'")
          .order(id: :desc)
          .offset(20)
          .destroy_all
        audit(user, "activate", theme)
        theme
      end
    end

    def self.destroy(id, revision:, user:)
      mutate do
        theme = find(id)
        check_revision!(theme, revision)
        if active["id"] == id
          raise Discourse::InvalidParameters.new(I18n.t("blog.themes.active_delete"))
        end
        PluginStore.remove(STORE, "theme:#{id}")
        audit(user, "delete", theme)
      end
    end

    def self.preview_token(theme)
      verifier.generate(
        { "id" => theme["id"], "revision" => theme["revision"] },
        expires_in: 1.hour,
      )
    end

    def self.from_preview(token)
      data = verifier.verified(token)
      raise Discourse::NotFound unless data.is_a?(Hash)
      if data["working"]
        stored = Discourse.redis.get("blog-theme-preview:#{data["working"]}")
        raise Discourse::NotFound unless stored
        return JSON.parse(stored)
      end
      theme = find(data["id"])
      raise Discourse::NotFound unless theme["revision"] == data["revision"]
      theme
    end

    def self.working_preview(attributes, user:)
      values = TEMPLATE_FIELDS.to_h { |field| [field, ""] }.merge(attributes.slice(*FIELDS))
      # Keep ordinary validation, but allow syntax errors to be inspected in the preview.
      validate!(values.merge(TEMPLATE_FIELDS.to_h { |field| [field, ""] }))
      TEMPLATE_FIELDS.each do |field|
        unless values[field].is_a?(String) && values[field].valid_encoding? &&
                 values[field].bytesize <= TemplateRenderer::MAX_TEMPLATE_BYTES
          raise Discourse::InvalidParameters.new(I18n.t("blog.themes.template_invalid"))
        end
      end
      key = SecureRandom.hex(32)
      DistributedMutex.synchronize("blog-theme-preview-#{user.id}") do
        index = "blog-theme-preview-index:#{user.id}"
        keys = JSON.parse(Discourse.redis.get(index) || "[]")
        keys << key
        if keys.length > 3
          keys
            .shift(keys.length - 3)
            .each { |old_key| Discourse.redis.del("blog-theme-preview:#{old_key}") }
        end
        Discourse.redis.setex("blog-theme-preview:#{key}", 15.minutes.to_i, values.to_json)
        Discourse.redis.setex(index, 15.minutes.to_i, keys.to_json)
      end
      verifier.generate({ "working" => key }, expires_in: 15.minutes)
    end

    def self.validate!(values)
      valid = FIELDS.all? { |field| values[field].is_a?(String) }
      valid &&= values["name"].strip.present? && values["name"].length <= 100
      valid &&=
        %w[accent_color paper_color ink_color].all? do |field|
          values[field].match?(/\A[0-9a-fA-F]{6}\z/)
        end
      valid &&=
        %w[css javascript].all? do |field|
          values[field].valid_encoding? && values[field].bytesize <= MAX_CODE_BYTES
        end
      raise Discourse::InvalidParameters.new(I18n.t("blog.themes.invalid")) unless valid
      TEMPLATE_FIELDS.each do |field|
        TemplateRenderer.validate!(values[field], page: field.delete_prefix("template_"))
      end
    end
    private_class_method :validate!

    def self.check_revision!(theme, revision)
      unless theme["revision"].to_s == revision.to_s
        raise Discourse::InvalidParameters.new(I18n.t("blog.themes.stale"))
      end
    end
    private_class_method :check_revision!

    def self.mutate(&block)
      DistributedMutex.synchronize("discourse-blog-themes") { PluginStoreRow.transaction(&block) }
    end
    private_class_method :mutate

    def self.audit(user, action, theme)
      StaffActionLogger.new(user).log_custom(
        "blog_theme_#{action}",
        theme_id: theme["id"],
        name: theme["name"],
        revision: theme["revision"],
      )
    end
    private_class_method :audit

    def self.verifier
      Rails.application.message_verifier(
        "discourse-blog-theme-#{RailsMultisite::ConnectionManagement.current_db}",
      )
    end
    private_class_method :verifier
  end
end
