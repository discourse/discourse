# frozen_string_literal: true

desc "Creates sample sentiment / emotion data"
task "ai:sentiment:populate", [:start_post] => [:environment] do |_, args|
  raise "Don't run this task in production!" if Rails.env.production?

  sentiment_model = DiscourseAi::Sentiment::PostClassification.active_model_name_for(:sentiment)
  emotion_model = DiscourseAi::Sentiment::PostClassification.active_model_name_for(:emotion)

  Post
    .joins(ActiveRecord::Base.sanitize_sql_array([<<~SQL, sentiment_model]))
        LEFT JOIN classification_results ON
          posts.id = classification_results.target_id AND
          classification_results.target_type = 'Post' AND
          model_used = ?
      SQL
    .where("classification_results.id IS NULL")
    .where("posts.id > ?", args[:start_post].to_i || 0)
    .find_each do |post|
      positive = rand(0.0..1.0)
      negative = rand(0.0..(1.0 - positive))
      neutral = 1 - positive - negative

      ClassificationResult.create!(
        target_id: post.id,
        model_used: sentiment_model,
        classification_type: "sentiment",
        target_type: "Post",
        classification: {
          neutral: neutral,
          positive: positive,
          negative: negative,
        },
      )
    end

  Post
    .joins(ActiveRecord::Base.sanitize_sql_array([<<~SQL, emotion_model]))
        LEFT JOIN classification_results ON
          posts.id = classification_results.target_id AND
          classification_results.target_type = 'Post' AND
          classification_results.model_used = ?
      SQL
    .where("classification_results.id IS NULL")
    .where("posts.id > ?", args[:start_post].to_i || 0)
    .find_each do |post|
      emotions =
        DiscourseAi::Sentiment::Emotions::LIST
          .shuffle
          .reduce({}) do |acc, emotion|
            current_sum = acc.values.sum
            acc.merge(emotion => rand(0.0..(1.0 - current_sum)))
          end

      emotions["neutral"] = 1 - (emotions.values.sum - emotions["neutral"])

      ClassificationResult.create!(
        target_id: post.id,
        model_used: emotion_model,
        classification_type: "sentiment",
        target_type: "Post",
        classification: emotions,
      )
    end
end
