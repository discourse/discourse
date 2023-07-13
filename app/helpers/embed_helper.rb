# frozen_string_literal: true

module EmbedHelper
  def embed_post_date(dt)
    current = Time.now

    if dt >= 1.day.ago
      distance_of_time_in_words(dt, current)
    else
      if dt.year == current.year
        dt.strftime("%e %b")
      else
        dt.strftime("%b '%y")
      end
    end
  end

  def get_html(post)
    key = "js.action_codes.#{post.action_code}"
    cooked = post.cooked.blank? ? I18n.t(key, when: nil).humanize : post.cooked

    raw PrettyText.format_for_email(cooked, post)
  end
end
