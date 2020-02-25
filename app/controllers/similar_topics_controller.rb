# frozen_string_literal: true

class SimilarTopicsController < ApplicationController

  class SimilarTopic
    def initialize(topic)
      @topic = topic
    end

    attr_reader :topic

    def blurb
      Search::GroupedSearchResults.blurb_for(@topic.try(:blurb))
    end
  end

  def index
    title = params.require(:title)
    raw = params[:raw]

    if title.length < SiteSetting.min_title_similar_length || !Topic.count_exceeds_minimum?
      return render json: []
    end

    topics = Topic.similar_to(title, raw, current_user).to_a
    topics.map! { |t| SimilarTopic.new(t) }
    render_serialized(topics, SimilarTopicSerializer, root: :similar_topics, rest_serializer: true)
  end

end
