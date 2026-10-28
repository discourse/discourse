# frozen_string_literal: true

module Live
  # In-call reactions offer the same emoji set the site curated for post
  # reactions. When post reactions are turned off, that setting's stock value
  # stands in, so an admin's tweaks to a disabled feature don't leak into calls.
  module Reactions
    ENABLED_SETTING = :discourse_reactions_enabled
    LIST_SETTING = :discourse_reactions_enabled_reactions
    MAIN_SETTING = :discourse_reactions_reaction_for_like
    ANY_EMOJI_SETTING = :discourse_reactions_allow_any_emoji

    # The characters custom emoji names are sanitized to, plus a skin tone.
    SHORTCODE = /\A[a-z0-9_+\-]{1,100}(?::t[1-6])?\z/

    # Used only when the post reactions settings aren't registered at all.
    FALLBACK = %w[heart +1 laughing open_mouth clap confetti_ball hugs].freeze

    def self.emojis
      return FALLBACK if !SiteSetting.has_setting?(LIST_SETTING)

      [setting(MAIN_SETTING), *setting(LIST_SETTING).to_s.split("|")].compact_blank.uniq
    end

    def self.allow_any_emoji?
      SiteSetting.has_setting?(ANY_EMOJI_SETTING) && !!setting(ANY_EMOJI_SETTING)
    end

    def self.valid?(emoji)
      return false if !emoji.is_a?(String)
      return true if emojis.include?(emoji)

      # Lookups key the shared emoji caches, misses included, so only
      # shortcode-shaped names may reach them.
      allow_any_emoji? && emoji.match?(SHORTCODE) && Emoji.exists?(emoji)
    end

    def self.setting(name)
      SiteSetting.get(ENABLED_SETTING) ? SiteSetting.get(name) : SiteSetting.defaults[name]
    end
    private_class_method :setting
  end
end
