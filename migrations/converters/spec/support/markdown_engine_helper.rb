# frozen_string_literal: true

# The extractor requires a markdown engine context, and building one means a
# V8 isolate evaluating the whole engine bundle (~70ms warm) — too much to pay
# per example. Contexts are stateless across scans, so they are memoized per
# configuration for the whole spec run; the handful of distinct configurations
# the suite uses stays alive until process exit.
module MarkdownEngineHelper
  def self.bundle
    @bundle ||= Migrations::Converters::MarkdownEngine::Bundle.load_or_build
  end

  def self.context_for(category_slugs: [], tag_names: [], custom_emoji_names: [], settings: {})
    key = [category_slugs.sort, tag_names.sort, custom_emoji_names.sort, settings.sort]
    @contexts ||= {}
    @contexts[key] ||= Migrations::Converters::MarkdownEngine::Context.new(
      bundle:,
      config:
        Migrations::Converters::MarkdownEngine::Config.new(
          source_settings: settings,
          category_slugs:,
          tag_names:,
          custom_emoji_names:,
        ),
    )
  end

  # An engine configuration matching a raw-extractor spec's Ruby-side name
  # sets. Whether a slug resolves as a category or a tag does not reach the
  # extracted rows (the forced type comes from the source's `::type` suffix),
  # so every name goes into both lookup sets; `parent:child` category paths
  # are addressed by their leaf slug in the engine's lookup.
  def self.context_for_names(hashtag_names:, custom_emoji_names: [], settings: {})
    names = hashtag_names.flat_map { |name| [name, name.split(":").last] }.uniq
    context_for(
      category_slugs: names,
      tag_names: names,
      custom_emoji_names:,
      settings: { "unicode_usernames" => true }.merge(settings),
    )
  end
end
