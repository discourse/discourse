# frozen_string_literal: true

class TopicsFilter
  def initialize(guardian:, scope: Topic, category_id: nil)
    @guardian = guardian
    @scope = scope
    @category = category_id.present? ? Category.find_by(id: category_id) : nil
  end

  def filter(status: nil)
    filter_status(@scope, status) if status
    @scope
  end

  private

  def filter_status(scope, status)
    case status
    when "open"
      @scope = @scope.where("NOT topics.closed AND NOT topics.archived")
    when "closed"
      @scope = @scope.where("topics.closed")
    when "archived"
      @scope = @scope.where("topics.archived")
    when "listed"
      @scope = @scope.where("topics.visible")
    when "unlisted"
      @scope = @scope.where("NOT topics.visible")
    when "deleted"
      if @guardian.can_see_deleted_topics?(@category)
        @scope = @scope.unscope(where: :deleted_at).where("topics.deleted_at IS NOT NULL")
      end
    end
  end
end
