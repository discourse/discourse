# frozen_string_literal: true
class PopulateTypeSourceInReviewable < ActiveRecord::Migration[7.2]
  def change
    # Migrate known reviewables to have a type_source
    # Copied from db/migrate/20250212045125_add_type_source_to_reviewable.rb
    known_reviewables = {
      "chat" => %w[ReviewableChatMessage],
      "core" => %w[ReviewableFlaggedPost ReviewableQueuedPost ReviewableUser ReviewablePost],
      "discourse-ai" => %w[ReviewableAiChatMessage ReviewableAiPost],
      "discourse-akismet" => %w[
        ReviewableAkismetPost
        ReviewableAkismetPostVotingComment
        ReviewableAkismetUser
      ],
      "discourse-antivirus" => %w[ReviewableUpload],
      "discourse-category-experts" => %w[ReviewableCategoryExpertSuggestion],
      "discourse-post-voting" => %w[ReviewablePostVotingComment],
    }

    known_reviewables.each do |plugin, types|
      types.each do |type|
        Reviewable.where(type: type, type_source: "unknown").update_all(type_source: plugin)
      end
    end
  end
end
