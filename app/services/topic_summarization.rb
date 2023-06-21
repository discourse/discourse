# frozen_string_literal: true

class TopicSummarization
  def initialize(strategy)
    @strategy = strategy
  end

  def summarize(topic)
    DistributedMutex.synchronize("toppic_summarization_#{topic.id}") do
      existing_summary = SummarySection.find_by(target: topic, meta_section_id: nil)
      return existing_summary.summarized_text if existing_summary

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

      cached_summary(summarization_result, targets_data.map(&:first), topic)

      summarization_result[:summary]
    end
  end

  def summary_targets(topic)
    topic.has_summary? ? best_replies(topic) : pick_selection(topic)
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

  def cached_summary(result, post_numbers, topic)
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
  end
end
