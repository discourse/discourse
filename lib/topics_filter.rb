# frozen_string_literal: true

class TopicsFilter
  def self.register_filter(matcher, &block)
    self.filters[matcher] = block
  end

  def self.filters
    @@filters ||= {}
  end

  register_filter(/\Astatus:([a-zA-Z]+)\z/i) do |topics, match|
    case match
    when "open"
      topics.where("NOT topics.closed AND NOT topics.archived")
    when "closed"
      topics.where("topics.closed")
    when "archived"
      topics.where("topics.archived")
    when "deleted"
      if @guardian.can_see_deleted_topics?(@category)
        topics.unscope(where: :deleted_at).where("topics.deleted_at IS NOT NULL")
      end
    end
  end

  def initialize(guardian:, scope: Topic, category_id: nil)
    @guardian = guardian
    @scope = scope
    @category = category_id.present? ? Category.find_by(id: category_id) : nil
  end

  def filter(input)
    input
      .to_s
      .scan(/(([^" \t\n\x0B\f\r]+)?(("[^"]+")?))/)
      .to_a
      .map do |(word, _)|
        next if word.blank?

        self.class.filters.each do |matcher, block|
          cleaned = word.gsub(/["']/, "")

          new_scope = instance_exec(@scope, $1, &block) if cleaned =~ matcher
          @scope = new_scope if !new_scope.nil?
        end
      end

    @scope
  end
end
