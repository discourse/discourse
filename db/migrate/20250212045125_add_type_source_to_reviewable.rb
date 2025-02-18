# frozen_string_literal: true
class AddTypeSourceToReviewable < ActiveRecord::Migration[7.2]
  def change
    add_column :reviewables, :type_source, :string, null: false, default: "unknown"

    # Migrate known reviewables to have a type_source
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
