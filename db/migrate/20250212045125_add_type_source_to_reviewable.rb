# frozen_string_literal: true
class AddTypeSourceToReviewable < ActiveRecord::Migration[7.2]
  def change
    add_column :reviewables, :type_source, :string, null: false, default: "unknown"

    # Migrate existing reviewables from plugins to have a type_source
    DiscoursePluginRegistry.reviewable_types_lookup.each do |reviewable|
      Reviewable.where(type: reviewable[:klass].sti_name).update_all(
        type_source: reviewable[:plugin],
      )
    end

    # Migrate existing reviewables from core to have a type_source
    Reviewable.sti_names.each do |type|
      if DiscoursePluginRegistry
           .reviewable_types_lookup
           .map { |r| r[:klass].sti_name }
           .include?(type)
        next
      end

      Reviewable.where(type: type).update_all(type_source: "core")
    end

    # Migrate existing reviewables from known plugins to have a type_source
    known_reviewables = {
      "discourse-ai" => %w[ReviewableAiChatMessage ReviewableAiPost],
      "discourse-akismet" => %w[
        ReviewableAkismetPost
        ReviewableAkismetPostVotingComment
        ReviewableAkismetUser
      ],
      "discourse-antivirus" => ["ReviewableUpload"],
      "discourse-category-experts" => ["ReviewableCategoryExpertSuggestion"],
      "discourse-post-voting" => ["ReviewablePostVotingComment"],
    }

    known_reviewables.each do |plugin, types|
      types.each do |type|
        Reviewable.where(type: type, type_source: "unknown").update_all(type_source: plugin)
      end
    end
  end
end
