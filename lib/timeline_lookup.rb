module TimelineLookup

  # Given an array of tuples (id, post_number, days_ago), return at most `max_values` worth of a
  # lookup table to help the front end timeline display dates associated with posts
  def self.build(tuples, max_values=300)
    result = []

    every = (tuples.size.to_f / max_values).ceil

    last_days_ago = -1
    tuples.each_with_index do |t, idx|
      next unless (idx % every) === 0

      days_ago = t[2]

      if (days_ago != last_days_ago)
        result << [idx+1, days_ago]
        last_days_ago = days_ago
      end

    end

    result
  end

end
