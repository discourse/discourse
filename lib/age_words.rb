module AgeWords

  def self.age_words(secs)
    return "&mdash;" if secs.blank?
    return FreedomPatches::Rails4.distance_of_time_in_words(Time.now, Time.now + secs)
  end

end
