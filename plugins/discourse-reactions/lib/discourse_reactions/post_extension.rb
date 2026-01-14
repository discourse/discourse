# frozen_string_literal: true

module DiscourseReactions::PostExtension
  attr_accessor :post_actions_with_reaction_users

  def self.prepended(base)
    base.has_many :reactions, class_name: "DiscourseReactions::Reaction"
    base.has_many :reactions_user, class_name: "DiscourseReactions::ReactionUser"
    base.attr_accessor :user_positively_reacted, :reaction_users_count
  end

  def emoji_reactions
    @emoji_reactions ||=
      begin
        self.reactions.select { |reaction| Emoji.exists?(reaction.reaction_value) }
      end
  end
end
