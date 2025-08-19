# frozen_string_literal: true

class TimeSniffer
  Interval = Struct.new(:from, :to)
  Event = Struct.new(:at)

  Context = Struct.new(:at, :timezone, :date_order)

  class SniffedTime
    attr_reader :year
    attr_reader :month
    attr_reader :day
    attr_reader :hours
    attr_reader :minutes
    attr_reader :seconds
    attr_reader :zone

    def initialize(year:, month:, day:, hours: 0, minutes: 0, seconds: 0, zone:)
      @year = year
      @month = month
      @day = day
      @hours = hours
      @minutes = minutes
      @seconds = seconds
      @zone = zone
    end

    def self.from_datetime(obj, zone)
      new(
        year: obj.year,
        month: obj.month,
        day: obj.day,
        hours: obj.hour,
        minutes: obj.minute,
        seconds: obj.second,
        zone: zone,
      )
    end

    def to_time
      Time.use_zone(self.zone) do
        Time.zone.parse(
          "#{self.year}-#{self.month}-#{self.day} #{self.hours}:#{self.minutes}:#{self.seconds}",
        )
      end
    end

    def with(**args)
      SniffedTime.new(**to_hash.merge(args))
    end

    def to_hash
      {
        year: self.year,
        month: self.month,
        day: self.day,
        hours: self.hours,
        minutes: self.minutes,
        seconds: self.seconds,
        zone: self.zone,
      }
    end

    def ==(other)
      return false unless other.kind_of?(SniffedTime)
      return false if @year != other.year
      return false if @month != other.month
      return false if @day != other.day
      return false if @hours != other.hours
      return false if @minutes != other.minutes
      return false if @seconds != other.seconds
      return false if @zone != other.zone
      true
    end
  end

  class << self
    def matchers
      @matchers ||= {}
    end

    def matcher(name, regex, &blk)
      matchers[name] = { regex: regex, blk: blk }
    end
  end

  class Parser
    UTC_REGEX = / ?(Z|UTC)/

    def initialize(input, context)
      @input = input
      @context = context
      @offset = 0
    end

    def parse_timezone
      m = input_from_offset.match(UTC_REGEX)
      if m && m.offset(0)[0] == 0
        self.offset += m.offset(0)[1]
        "UTC"
      end
    end

    def parse_space
      if input[offset] == " "
        self.offset += 1
        true
      else
        false
      end
    end

    def parse_time(relative_to, immediate:)
      time, start_offset, stop_offset = peek_time(relative_to)
      if time && (!immediate || start_offset == 0)
        self.offset += stop_offset
        time
      end
    end

    def parse_date
      date_match = DATE_REGEX.match(input_from_offset)
      if date_match
        day, month =
          case @context.date_order
          when :us
            [date_match[2], date_match[1]]
          when :sane
            [date_match[1], date_match[2]]
          end

        year = date_match[3]
        year =
          case year.size
          when 2
            century = @context.at.year - (@context.at.year % 100)
            last_century = century - 100

            choices = [century + year.to_i, last_century + year.to_i]

            choices.sort_by { |x| (@context.at.year - x).abs }[0]
          when 4
            year.to_i
          end

        result =
          SniffedTime.new(year: year, month: month.to_i, day: day.to_i, zone: @context.timezone)

        self.offset += date_match.offset(0)[1]
        result
      end
    end

    def parse_time_with_timezone(relative_to, immediate:)
      result = parse_time(relative_to, immediate: immediate)
      if result
        zone = parse_timezone

        result = result.with(zone: zone) if zone

        result
      end
    end

    def parse_date_time(relative_to)
      date = parse_date
      if date
        if parse_space
          datetime = parse_time_with_timezone(date, immediate: true)
          datetime ? [false, datetime] : [true, date]
        else
          [true, date]
        end
      elsif relative_to
        datetime = parse_time_with_timezone(relative_to, immediate: false)
        datetime ? [false, datetime] : [true, nil]
      end
    end

    def parse_range
      if x = parse_date_time(nil)
        from_is_date, from = x
        to_is_date, to = parse_date_time(from)

        if to
          if to_is_date
            Interval.new(from.to_time, to.to_time + 1.day)
          else
            Interval.new(from.to_time, to.to_time)
          end
        else
          from_is_date ? Interval.new(from.to_time, from.to_time + 1.day) : Event.new(from.to_time)
        end
      end
    end

    def input_from_offset
      self.input[self.offset..-1]
    end

    def peek_time(relative_to)
      m = self.input_from_offset.match(TIME_REGEX)
      if m
        parsed =
          relative_to.with(
            hours: m[1].to_i,
            minutes: m[2].to_i,
            seconds: 0,
            zone: @context.timezone,
          )

        [parsed, *m.offset(0)]
      end
    end

    attr_reader :input
    attr_accessor :offset
  end

  matcher(:yesterday, /yesterday/) do |m|
    today = at.to_date
    yesterday = today - 1

    Interval.new(
      SniffedTime.from_datetime(yesterday.to_datetime, timezone).to_time,
      SniffedTime.from_datetime(today.to_datetime, timezone).to_time,
    )
  end

  matcher(:tomorrow, /tomorrow/i) do |_|
    tomorrow = at.to_date + 1
    the_day_after_tomorrow = tomorrow + 1

    Interval.new(
      SniffedTime.from_datetime(tomorrow.to_datetime, timezone).to_time,
      SniffedTime.from_datetime(the_day_after_tomorrow.to_datetime, timezone).to_time,
    )
  end

  TIME_REGEX = /(\d{1,2}):(\d{2})/

  matcher(:time, TIME_REGEX) do |m|
    times = input.scan(TIME_REGEX).to_a
    from, to = times[0..2]
    if to
      Interval.new(
        SniffedTime.new(
          year: at.year,
          month: at.month,
          day: at.day,
          hours: from[0].to_i,
          minutes: from[1].to_i,
          seconds: 0,
          zone: timezone,
        ).to_time,
        SniffedTime.new(
          year: at.year,
          month: at.month,
          day: at.day,
          hours: to[0].to_i,
          minutes: to[1].to_i,
          seconds: 0,
          zone: timezone,
        ).to_time,
      )
    else
      Event.new(
        SniffedTime.new(
          year: at.year,
          month: at.month,
          day: at.day,
          hours: from[0].to_i,
          minutes: from[1].to_i,
          seconds: 0,
          zone: timezone,
        ).to_time,
      )
    end
  end

  DATE_SEPARATOR = %r{[-/]}
  DATE_REGEX = /((?:^|\s)\d{1,2})#{DATE_SEPARATOR}(\d{1,2})#{DATE_SEPARATOR}(\d{2,4})/

  matcher(:date, DATE_REGEX) { |m| Parser.new(input, @context).parse_range }

  def initialize(input, at: DateTime.now, timezone:, date_order:, matchers:, raise_errors: false)
    @input = input
    @at = at
    @timezone = timezone
    @date_order = date_order
    @context = Context.new(@at, @timezone, @date_order)
    @matchers = matchers
    @raise_errors = raise_errors
  end

  def sniff
    @matchers.each do |matcher_name|
      matcher = self.class.matchers[matcher_name]
      regex, blk = matcher.values_at(:regex, :blk)

      match = regex.match(@input)
      if match
        begin
          result = instance_exec(match, &blk)
        rescue Exception => e
          raise if @raise_errors
        else
          return result if result
        end
      end
    end

    nil
  end

  private

  attr_reader :input
  attr_reader :at
  attr_reader :timezone
  attr_reader :date_order
end
