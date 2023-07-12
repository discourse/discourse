# frozen_string_literal: true

class TopicSummarization
  def initialize(strategy)
    @strategy = strategy
  end

  def summarize(topic, user)
    existing_summary = SummarySection.find_by(target: topic, meta_section_id: nil)

    # For users without permissions to generate a summary, we return what we have cached.
    # Existing summary shouldn't be nil in this scenario because the controller checks its existence.
    return existing_summary if !user || !Summarization::Base.can_request_summary_for?(user)

    return existing_summary if existing_summary && fresh?(existing_summary, topic)

    delete_cached_summaries_of(topic) if existing_summary

    content = {
      resource_path: "#{Discourse.base_path}/t/-/#{topic.id}",
      content_title: topic.title,
      contents: [],
    }

    targets_data = summary_targets(topic).pluck(:post_number, :raw, :username)

    targets_data.map do |(pn, raw, username)|
      content[:contents] << { poster: username, id: pn, text: raw }
    end

    summarization_result = strategy.summarize(content)

    cache_summary(summarization_result, targets_data.map(&:first), topic)
  end

  def summary_targets(topic)
    @targets ||= topic.has_summary? ? best_replies(topic) : pick_selection(topic)
  end

  private

  attr_reader :strategy

  def best_replies(topic)
    Post
      .summary(topic.id)
      .where("post_type = ?", Post.types[:regular])
      .where("NOT hidden")
      .joins(:user)
      .order(:post_number)
  end

  def pick_selection(topic)
    posts =
      Post
        .where(topic_id: topic.id)
        .where("post_type = ?", Post.types[:regular])
        .where("NOT hidden")
        .order(:post_number)

    post_numbers = posts.limit(5).pluck(:post_number)
    post_numbers += posts.reorder("posts.score desc").limit(50).pluck(:post_number)
    post_numbers += posts.reorder("post_number desc").limit(5).pluck(:post_number)

    Post
      .where(topic_id: topic.id)
      .joins(:user)
      .where("post_number in (?)", post_numbers)
      .order(:post_number)
  end

  def delete_cached_summaries_of(topic)
    SummarySection.where(target: topic).destroy_all
  end

  def fresh?(summary, topic)
    return true if summary.created_at > 12.hours.ago
    latest_post_to_summarize = summary_targets(topic).last.post_number

    latest_post_to_summarize <= summary.content_range.to_a.last
  end

  def cache_summary(result, post_numbers, topic)
    main_summary =
      SummarySection.create!(
        target: topic,
        algorithm: strategy.model,
        content_range: (post_numbers.first..post_numbers.last),
        summarized_text: result[:summary],
        original_content_sha: Digest::SHA256.hexdigest(post_numbers.join),
      )

    result[:chunks].each do |chunk|
      SummarySection.create!(
        target: topic,
        algorithm: strategy.model,
        content_range: chunk[:ids].min..chunk[:ids].max,
        summarized_text: chunk[:summary],
        original_content_sha: Digest::SHA256.hexdigest(chunk[:ids].join),
        meta_section_id: main_summary.id,
      )
    end

    main_summary
  end
end
