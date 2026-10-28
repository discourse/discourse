# frozen_string_literal: true

module Live
  # In-call reactions offer the same emoji set the site curated for post
  # reactions. When post reactions are turned off, that setting's stock value
  # stands in, so an admin's tweaks to a disabled feature don't leak into calls.
  module Reactions
    ENABLED_SETTING = :discourse_reactions_enabled
    LIST_SETTING = :discourse_reactions_enabled_reactions
    MAIN_SETTING = :discourse_reactions_reaction_for_like

    # Used only when the post reactions settings aren't registered at all.
    FALLBACK = %w[heart +1 laughing open_mouth clap confetti_ball hugs].freeze

    def self.emojis
      return FALLBACK if !SiteSetting.has_setting?(LIST_SETTING)

      read =
        if SiteSetting.get(ENABLED_SETTING)
          ->(name) { SiteSetting.get(name) }
        else
          ->(name) { SiteSetting.defaults[name] }
        end

      [read.(MAIN_SETTING), *read.(LIST_SETTING).to_s.split("|")].compact_blank.uniq
    end

    def self.valid?(emoji)
      emojis.include?(emoji)
    end
  end
end
