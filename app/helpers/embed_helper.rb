module EmbedHelper

  def embed_post_date(dt)
    current = Time.now

    if dt >= 1.day.ago
      distance_of_time_in_words(dt, current)
    else
      if dt.year == current.year
        dt.strftime("%e %b")
      else
        dt.strftime("%e %b %Y")
      end
    end
  end

end

