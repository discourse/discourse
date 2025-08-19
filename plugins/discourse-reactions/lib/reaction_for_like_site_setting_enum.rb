# frozen_string_literal: true

require_dependency "enum_site_setting"

class ReactionForLikeSiteSettingEnum < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val }
  end

  def self.values
    @values =
      begin
        excluded_from_like = SiteSetting.discourse_reactions_excluded_from_like.to_s.split("|")

        reactions =
          DiscourseReactions::Reaction
            .valid_reactions
            .map { |reaction| { name: reaction, value: reaction } }
            .reject { |reaction| excluded_from_like.include?(reaction[:value]) }
      end
  end
end
