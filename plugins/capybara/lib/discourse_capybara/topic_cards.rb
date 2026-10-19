# frozen_string_literal: true

module ::DiscourseCapybara
  module TopicCards
    private

    def build_floater_card(board, column, params, guardian)
      if Rails.env.production? || !SiteSetting.capybara_enabled ||
           board.id != CodexBoardBot::BOARD_ID
        return super
      end

      raise Discourse::InvalidParameters if params.title.blank?
      category_ids = board.category_ids.presence || [SiteSetting.uncategorized_category_id]
      category = Category.topic_create_allowed(guardian).where(id: category_ids).first
      unless category && guardian.can_create_topic_on_category?(category)
        raise Discourse::InvalidAccess
      end

      post =
        PostCreator.create!(
          guardian.user,
          title: params.title,
          raw: params.notes.presence || params.title,
          category: category.id,
          tags: Tag.where(id: board.tag_ids).pluck(:name),
          skip_validations: true,
        )
      topic_params =
        params.class.new(
          **params.to_hash.merge(topic_id: post.topic_id),
          options: context[:options],
        )
      build_topic_card(board, column, topic_params, guardian, options: context[:options])
    end
  end
end
