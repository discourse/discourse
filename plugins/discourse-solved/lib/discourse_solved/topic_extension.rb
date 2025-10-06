# frozen_string_literal: true

module DiscourseSolved::TopicExtension
  extend ActiveSupport::Concern

  prepended { has_one :solved, class_name: "DiscourseSolved::SolvedTopic", dependent: :destroy }

  def accepted_answer_post_info
    return unless solved
    return unless answer_post = solved.answer_post

    answer_post_user = answer_post.user || Discourse.system_user
    accepter = solved.accepter || self.user || Discourse.system_user

    excerpt =
      if SiteSetting.solved_quote_length > 0
        PrettyText.excerpt(
          answer_post.cooked,
          SiteSetting.solved_quote_length,
          keep_emoji_images: true,
        )
      else
        nil
      end

    accepted_answer = {
      post_number: answer_post.post_number,
      username: answer_post_user.username,
      name: answer_post_user.name,
      excerpt:,
    }

    if SiteSetting.show_who_marked_solved
      accepted_answer[:accepter_name] = accepter.name
      accepted_answer[:accepter_username] = accepter.username
    end

    if !SiteSetting.enable_names || !SiteSetting.display_name_on_posts
      accepted_answer[:name] = nil
      accepted_answer[:accepter_name] = nil
    end

    accepted_answer
  end
end
