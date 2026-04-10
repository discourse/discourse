# frozen_string_literal: true

module DiscourseSolved::TopicExtension
  extend ActiveSupport::Concern

  prepended { has_one :solved, class_name: "DiscourseSolved::SolvedTopic", dependent: :destroy }

  def solved_auto_close_hours
    hours = category&.solved_auto_close_hours || 0
    hours.zero? ? SiteSetting.solved_topics_auto_close_hours : hours
  end

  def accepted_answers_post_info # renamed plural
    return [] unless solved

    solved
      .topic_answers
      .includes(:post, :accepter)
      .filter_map do |ta|
        post = ta.post
        next unless post

        post_user = post.user || Discourse.system_user
        accepter = ta.accepter || self.user || Discourse.system_user
        excerpt = SiteSetting.solved_quote_length > 0 ? post.cooked : nil

        answer = {
          post_number: post.post_number,
          username: post_user.username,
          name: post_user.name,
          avatar_template: post_user.avatar_template,
          excerpt:,
        }

        if SiteSetting.show_who_marked_solved
          answer[:accepter_name] = accepter.name
          answer[:accepter_username] = accepter.username
        end

        if !SiteSetting.enable_names || !SiteSetting.display_name_on_posts
          answer[:name] = nil
          answer[:accepter_name] = nil
        end

        answer
      end
  end
end
