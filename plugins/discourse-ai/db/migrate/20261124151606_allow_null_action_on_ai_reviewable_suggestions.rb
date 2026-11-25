# frozen_string_literal: true
class AllowNullActionOnAiReviewableSuggestions < ActiveRecord::Migration[8.1]
  def change
    change_column_null :ai_reviewable_suggestions, :action_name, true
    change_column_null :ai_reviewable_suggestions, :confidence, true
  end
end
