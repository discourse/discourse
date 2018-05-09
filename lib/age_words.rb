module AgeWords

  def self.age_words(secs)
    if secs.blank?
      "&mdash;"
      # &mdash; is an em dash (—)
    else
      now = Time.now
      FreedomPatches::Rails4.distance_of_time_in_words(now, now + secs)
      # http://www.rubydoc.info/github/discourse/discourse/FreedomPatches%2FRails4.distance_of_time_in_words
      # Discourse 独有的
    end
  end

end
