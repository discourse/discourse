module Topics
  module AutoCloser
    extend self

    # Valid arguments:
    #  * An integer, which is the number of hours from now to close the topic.
    #  * A time, like "12:00", which is the time at which the topic will close in the current day
    #    or the next day if that time has already passed today.
    #  * A timestamp, like "2013-11-25 13:00", when the topic should close.
    #  * A timestamp with timezone in JSON format. (e.g., "2013-11-26T21:00:00.000Z")
    #  * nil, to prevent the topic from automatically closing.
    def get_closer_method(arg)
      auto_closes_by_json(arg) ||
        auto_closes_by_hour_string(arg) ||
        auto_closes_by_num_hours(arg) ||
        does_not_auto_close
    end

  protected

    def auto_closes_by_json(timestamp)
      matches = /^([\d]{1,2}):([\d]{1,2})$/.match(timestamp.to_s.strip).to_a
      return if matches.empty?
      ->(closeable) {
        close_via_json_date_time(closeable, matches)
      }
    end

    def auto_closes_by_hour_string(hour)
      return unless hour.to_s.include?('-') && timestamp = Time.zone.parse(hour.to_s)
      ->(closeable) {
        close_via_hour_string(closeable, timestamp)
      }
    end

    def auto_closes_by_num_hours(num_hours)
      return if num_hours.to_i == 0
      ->(closeable) {
        close_via_num_hours(closeable, num_hours)
      }
    end

    def does_not_auto_close
      ->(closeable) {
        closeable.auto_close_at = nil
        closeable.auto_close_started_at = nil
      }
    end

    def close_via_json_date_time(closeable, matches)
      now = Time.zone.now
      closeable.auto_close_at = Time.zone.local(now.year, now.month, now.day,
                                                matches[1].to_i, matches[2].to_i)
      if closeable.auto_close_at < now
        closeable.auto_close_at += 1.day
      else
        nil
      end
    end

    def close_via_hour_string(closeable, timestamp)
      closeable.auto_close_at = timestamp
      if timestamp < Time.zone.now
        closeable.errors.add(:auto_close_at, :invalid)
      else
        nil
      end
    end

    def close_via_num_hours(closeable, num_hours)
      num_hours = num_hours.to_i
      if num_hours > 0
        closeable.auto_close_at = num_hours.hours.from_now
      else
        nil
      end
    end
  end
end
