# frozen_string_literal: true
class AddTypeSourceToReviewable < ActiveRecord::Migration[7.2]
  def change
    add_column :reviewables, :type_source, :string, null: false, default: "unknown"

    # Migrate known reviewables to have a type_source
    # This process is repeated in db/post_migrate/20250306045125_populate_type_source_in_reviewable.rb,
    # to ensure that the column is populated after migrated servers are deployed to production.
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
      DB.exec(
        "UPDATE reviewables SET type_source = :plugin WHERE type_source = 'unknown' AND type IN (:types)",
        plugin: plugin,
        types: types,
      )
    end
  end
end
