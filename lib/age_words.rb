module AgeWords

  def self.age_words(secs)
    if secs.blank?
      "&mdash;"
    else
      now = Time.now
      FreedomPatches::Rails4.distance_of_time_in_words(now, now + secs)
    end
  end

end
