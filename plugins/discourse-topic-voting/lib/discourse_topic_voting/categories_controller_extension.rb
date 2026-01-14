# frozen_string_literal: true

module DiscourseTopicVoting
  module CategoriesControllerExtension
    def category_params
      @vote_enabled ||=
        !!ActiveRecord::Type::Boolean.new.cast(params&.[](:custom_fields)&.[](:enable_topic_voting))

      category_params = super

      if @vote_enabled && !@category&.discourse_topic_voting_category_setting
        category_params[:discourse_topic_voting_category_setting_attributes] = {}
      elsif !@vote_enabled && @category&.discourse_topic_voting_category_setting
        category_params[:discourse_topic_voting_category_setting_attributes] = {
          id: @category.discourse_topic_voting_category_setting.id,
          _destroy: "1",
        }
      end

      category_params
    end
  end
end
