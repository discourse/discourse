# frozen_string_literal: true

# Makes the digests of the two heaviest server-generated asset families pure
# content functions so their responses can be browser-cached across examples
# (see static_asset_cache_control.rb, which exempts them from `no-store`).
#
# Both digests are honest in production but lie under transactional tests:
#
# * `Stylesheet::Manager::Builder#color_scheme_digest` keys on
#   `color_scheme.id`-`color_scheme.version`. `fab!`/`let_it_be` reuse record
#   ids while the data rolls back, so two examples can publish *different*
#   compiled CSS under the *identical* digest URL — the exact staleness class
#   that produced iter-196's three CI failures once the browser cache became
#   worker-lifetime. Keying on the resolved colors themselves (the same hash
#   `Stylesheet::Importer` feeds to the compiler) makes a digest collision
#   imply byte-identical output.
#
# * `Stylesheet::Manager::Builder#settings_digest` keys on `updated_at`
#   timestamps of theme settings/yaml fields, which can repeat across
#   examples under `freeze_time` while the values differ. Key on the values.
#
# * `ExtraLocalesController.js_digests` memoizes site-specific bundle digests
#   (`overrides`, `mf`) process-wide; fabricated TranslationOverride rows
#   never invalidate it because `dump_caches`-style hooks run `after_commit`,
#   and the rollback at example end couldn't restore the memo anyway. Folding
#   a fingerprint of the override rows into the memo key makes the memo
#   exactly as fresh as the data. Shared bundles (`main`, `admin`, `wizard`)
#   depend only on per-run-constant locale files and keep the stock memo.
module TestHonestGeneratedAssetDigests
  module StylesheetBuilder
    def color_scheme_digest
      cs = @color_scheme || theme&.color_scheme
      return super if !cs

      colors_fingerprint = cs.resolved_colors.sort.map! { |pair| pair.join(":") }.join(",")
      fonts = "#{SiteSetting.base_font}-#{SiteSetting.heading_font}"
      theme_color_defs = resolve_baked_field(:common, :color_definitions)

      Digest::SHA1.hexdigest(
        "#{current_hostname}-#{RailsMultisite::ConnectionManagement.current_db}-" \
          "#{colors_fingerprint}-#{theme_color_defs}-#{Stylesheet::Manager.fs_asset_cachebuster}-#{fonts}",
      )
    end

    def settings_digest
      themes =
        if !theme
          []
        elsif Theme.is_parent_theme?(theme.id)
          @manager.load_themes(@manager.theme_ids)
        else
          [@manager.get_theme(theme.id)]
        end

      fields =
        themes.flat_map do |t|
          t.yaml_theme_fields.map { |f| "y#{f.theme_id}:#{f.name}:#{f.value}" }
        end

      settings =
        themes.flat_map do |t|
          t.theme_settings.map { |s| "s#{s.theme_id}:#{s.name}:#{s.data_type}:#{s.value}" }
        end

      Digest::SHA1.hexdigest(fields.sort!.concat(settings.sort!).join("|"))
    end
  end

  module ExtraLocales
    def bundle_js_hash(bundle, locale:)
      return super if !bundle.in?(ExtraLocalesController::SITE_SPECIFIC_BUNDLES)

      fingerprint =
        Digest::SHA1.hexdigest(
          TranslationOverride
            .order(:id)
            .pluck(:locale, :translation_key, :value, :status)
            .flatten
            .join("\x1f"),
        )

      site = RailsMultisite::ConnectionManagement.current_db
      site_cache = js_digests[:site_specific][site] ||= {}
      site_cache["#{bundle}_#{locale}_#{fingerprint}"] ||= begin
        js = bundle_js(bundle, locale: locale)
        js.present? ? digest_for_content(js) : nil
      end
    end
  end
end

Stylesheet::Manager::Builder.prepend(TestHonestGeneratedAssetDigests::StylesheetBuilder)
ExtraLocalesController.singleton_class.prepend(TestHonestGeneratedAssetDigests::ExtraLocales)
