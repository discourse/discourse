# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::AUTO_RESPONDER) do
  field :word_answer_list, component: :"key-value", accepts_placeholders: true
  field :answering_user, component: :user
  field :once, component: :boolean

  version 1

  triggerables %i[post_created_edited pm_created]

  placeholder :sender_username
  placeholder :word

  script do |context, fields, automation|
    key = DiscourseAutomation::AUTO_RESPONDER_TRIGGERED_IDS

    answering_username = fields.dig("answering_user", "value") || Discourse.system_user.username
    placeholders = { sender_username: answering_username }
    post = context["post"]
    next if !post.topic

    next if fields.dig("once", "value") && post.topic.custom_fields[key]&.include?(automation.id)

    answers = Set.new
    word_answer_list_json = fields.dig("word_answer_list", "value")
    next if word_answer_list_json.blank?

    word_answer_list = JSON.parse(word_answer_list_json)
    next if word_answer_list.blank?

    word_answer_list.each do |word_answer_pair|
      if word_answer_pair["key"].blank?
        answers.add(word_answer_pair)
        next
      end

      if post.is_first_post?
        if match = post.topic.title.match(/\b(#{word_answer_pair["key"]})\b/i)
          word_answer_pair["key"] = match.captures.first
          answers.add(word_answer_pair)
          next
        end
      end

      if match = post.raw.match(/\b(#{word_answer_pair["key"]})\b/i)
        word_answer_pair["key"] = match.captures.first
        answers.add(word_answer_pair)
      end
    end

    next if answers.blank?

    answering_user = User.find_by(username: answering_username)
    next if post.user == answering_user

    replies =
      post
        .replies
        .where(user_id: answering_user.id, deleted_at: nil)
        .secured(Guardian.new(post.user))

    next if replies.present?

    answers =
      answers
        .to_a
        .map do |answer|
          utils.apply_placeholders(answer["value"], placeholders.merge(key: answer["key"]))
        end
        .join("\n\n")

    automation.add_id_to_custom_field(post.topic, key)

    PostCreator.create!(
      answering_user,
      topic_id: post.topic.id,
      reply_to_post_number: post.post_number,
      raw: answers,
      skip_validations: true,
    )
  end
end
