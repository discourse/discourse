# frozen_string_literal: true

module DiscourseReactions
  class Reaction < ActiveRecord::Base
    self.table_name = "discourse_reactions_reactions"

    enum :reaction_type, { emoji: 0 }

    has_many :reaction_users, class_name: "DiscourseReactions::ReactionUser"
    has_many :users, through: :reaction_users
    belongs_to :post

    scope :positive, -> { where(reaction_value: self.positive_reactions) }
    scope :negative_or_neutral, -> { where(reaction_value: self.negative_or_neutral_reactions) }
    scope :by_user,
          ->(user) do
            joins(:reaction_users).where(discourse_reactions_reaction_users: { user_id: user.id })
          end

    def self.valid_reactions
      Set[
        DiscourseReactions::Reaction.main_reaction_id,
        *SiteSetting.discourse_reactions_enabled_reactions.to_s.split("|")
      ]
    end

    def self.main_reaction_id
      SiteSetting.discourse_reactions_reaction_for_like.gsub("-", "")
    end

    def self.reactions_excluded_from_like
      SiteSetting.discourse_reactions_excluded_from_like.to_s.split("|")
    end

    def self.reactions_counting_as_like
      Set[
        *(
          valid_reactions.to_a - reactions_excluded_from_like -
            [DiscourseReactions::Reaction.main_reaction_id]
        ).flatten
      ]
    end
  end
end

# == Schema Information
#
# Table name: discourse_reactions_reactions
#
#  id                   :bigint           not null, primary key
#  post_id              :integer
#  reaction_type        :integer
#  reaction_value       :string
#  reaction_users_count :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_discourse_reactions_reactions_on_post_id  (post_id)
#  reaction_type_reaction_value                    (post_id,reaction_type,reaction_value) UNIQUE
#
