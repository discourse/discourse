# frozen_string_literal: true

module DiscourseReactions
  # There is some slightly complex logic around reactions that
  # is not immediately apparent. Some reactions also count as
  # a PostAction "like" and some do not. There are three states
  # that can happen when a user reacts to a post:
  #
  # * A PostAction record is created _without_ a ReactionUser. This
  #   happens when the main_reaction_id (discourse_reactions_reaction_for_like)
  #   is used.
  # * A ReactionUser record is created _without_ a PostAction. This
  #   happens when a reaction that does not count as a "like" is used
  #   (discourse_reactions_excluded_from_like)
  # * Both a PostAction and ReactionUser are created. This happens
  #   when a reaction that counts as a "like" is used that is _not_
  #   the main_reaction_id and is _not_ in the excluded_from_like list.
  #
  # When the discourse_reactions_excluded_from_like setting changes,
  # we sync the ReactionUser and PostAction records to delete the PostAction
  # records that are no longer necessary. Changing the main_reaction_id
  # does not alter history, and as such it is not recommended to do this.
  class ReactionUser < ActiveRecord::Base
    self.table_name = "discourse_reactions_reaction_users"

    belongs_to :reaction, class_name: "DiscourseReactions::Reaction", counter_cache: true
    belongs_to :user
    belongs_to :post

    delegate :username, to: :user, allow_nil: true
    delegate :avatar_template, to: :user, allow_nil: true
    delegate :name, to: :user, allow_nil: true

    def can_undo?
      self.created_at > SiteSetting.post_undo_action_window_mins.minutes.ago
    end

    def post_action_like
      @post_action_like ||=
        PostAction.find_by(
          user_id: self.user_id,
          post_id: self.post_id,
          post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
        )
    end

    def reload
      @post_action_like = nil
      super
    end
  end
end

# == Schema Information
#
# Table name: discourse_reactions_reaction_users
#
#  id          :bigint           not null, primary key
#  reaction_id :bigint
#  user_id     :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  post_id     :integer
#
# Indexes
#
#  index_discourse_reactions_reaction_users_on_reaction_id  (reaction_id)
#  reaction_id_user_id                                      (reaction_id,user_id) UNIQUE
#  user_id_post_id                                          (user_id,post_id) UNIQUE
#
