module EmbedHelper
  def embed_post_date(dt)
    current = Time.now

    if dt >= 1.day.ago
      distance_of_time_in_words(dt, current)
    else
      dt.year == current.year ? dt.strftime('%e %b') : dt.strftime("%b '%y")
    end
  end

  def get_html(post)
    raw PrettyText.format_for_email(post.cooked, post)
  end
end
