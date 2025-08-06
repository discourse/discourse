# frozen_string_literal: true

def classify(content)
  ::DiscourseAi::Inference::DiscourseClassifier.perform!(
    "#{SiteSetting.ai_toxicity_inference_service_api_endpoint}/api/v1/classify",
    SiteSetting.ai_toxicity_inference_service_api_model,
    content,
    SiteSetting.ai_toxicity_inference_service_api_key,
  )
end

desc "Uses existing flagged posts to suggest a configuration threshold"
task "ai:toxicity:calibration_stats", [:set_size] => [:environment] do |_, args|
  flag_agreed =
    PostAction
      .where(post_action_type_id: 4, disagreed_at: nil, deferred_at: nil)
      .where("post_actions.user_id > 0")
      .includes(:post, :user)
      .where(user: { admin: false, moderator: false })
      .where("posts.raw IS NOT NULL")
      .order(created_at: :desc)
      .limit(args[:set_size])
      .pluck(:raw)

  flag_not_agreed =
    PostAction
      .where(post_action_type_id: 4)
      .where("(disagreed_at IS NOT NULL OR deferred_at IS NOT NULL)")
      .where("post_actions.user_id > 0")
      .includes(:post, :user)
      .where(user: { admin: false, moderator: false })
      .where("posts.raw IS NOT NULL")
      .order(created_at: :desc)
      .limit(args[:set_size])
      .pluck(:raw)

  flag_agreed_scores = flag_agreed.map { classify(_1) }
  flag_not_agreed_scores = flag_not_agreed.map { classify(_1) }

  DiscourseAi::Toxicity::Classifier::CLASSIFICATION_LABELS.each do |label|
    puts "Label: #{label}"

    label_agreed_scores = flag_agreed_scores.map { _1[label] }
    label_not_agreed_scores = flag_not_agreed_scores.map { _1[label] }

    puts "Flagged posts score:"
    puts "Max: #{label_agreed_scores.max}"
    puts "Min: #{label_agreed_scores.min}"
    puts "Avg: #{label_agreed_scores.sum(0.0) / label_agreed_scores.size}"
    puts "Median: #{label_agreed_scores.sort[label_agreed_scores.size / 2]}"
    puts "Stddev: #{Math.sqrt(label_agreed_scores.map { (_1 - label_agreed_scores.sum(0.0) / label_agreed_scores.size)**2 }.sum(0.0) / label_agreed_scores.size)}"

    puts "Flagged posts score:"
    puts "Max: #{label_not_agreed_scores.max}"
    puts "Min: #{label_not_agreed_scores.min}"
    puts "Avg: #{label_not_agreed_scores.sum(0.0) / label_not_agreed_scores.size}"
    puts "Median: #{label_not_agreed_scores.sort[label_not_agreed_scores.size / 2]}"
    puts "Stddev: #{Math.sqrt(label_not_agreed_scores.map { (_1 - label_not_agreed_scores.sum(0.0) / label_not_agreed_scores.size)**2 }.sum(0.0) / label_not_agreed_scores.size)}"

    best_cutoff = 0
    best_cutoff_score = 0

    (0..100)
      .step(1)
      .each do |cutoff|
        score =
          label_agreed_scores.count { _1 > cutoff } + label_not_agreed_scores.count { _1 <= cutoff }

        if score > best_cutoff_score
          best_cutoff_score = score
          best_cutoff = cutoff
        end
      end

    puts "Recommended ai_toxicity_flag_threshold_#{label} value: #{best_cutoff}"
  end
end
