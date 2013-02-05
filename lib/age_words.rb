module AgeWords

  def self.age_words(secs)
    return "&mdash;" if secs.blank?

    mins = (secs / 60.0)
    hours = (mins / 60.0)
    days = (hours / 24.0)
    months = (days / 30.0)
    years = (months / 12.0)

    return "#{years.floor}y" if years > 1
    return "#{months.floor}mo" if months > 1
    return "#{days.floor}d" if days > 1
    return "#{hours.floor}h" if hours > 1
    return "&lt; 1m" if mins < 1
    return "#{mins.floor}m"
  end

end