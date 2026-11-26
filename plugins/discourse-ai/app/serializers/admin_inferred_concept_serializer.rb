# frozen_string_literal: true

class AdminInferredConceptSerializer < InferredConceptSerializer
  attributes :parent_name, :topics_count, :posts_count, :children_count

  def parent_name
    object.parent&.name
  end

  def topics_count
    if @options.key?(:topics_counts)
      @options[:topics_counts][object.id] || 0
    else
      object.inferred_concept_topics.count
    end
  end

  def posts_count
    if @options.key?(:posts_counts)
      @options[:posts_counts][object.id] || 0
    else
      object.inferred_concept_posts.count
    end
  end

  def children_count
    if @options.key?(:children_counts)
      @options[:children_counts][object.id] || 0
    else
      object.children.count
    end
  end
end
