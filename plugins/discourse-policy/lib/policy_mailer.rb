# frozen_string_literal: true

class DiscoursePolicy::PolicyMailer
  class << self
    def send_email(user, post)
      Jobs.enqueue(:user_email, type: "policy_email", user_id: user.id, post_id: post.id)
    end
  end
end
