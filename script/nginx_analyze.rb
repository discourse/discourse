require 'date'

class LogAnalyzer

  class LineParser


    # log_format log_discourse '[$time_local] $remote_addr "$request" "$http_user_agent" "$sent_http_x_discourse_route" $status $bytes_sent "$http_referer" $upstream_response_time $request_time "$sent_http_x_discourse_username"';

    attr_accessor :time, :ip_address, :url, :route, :user_agent, :rails_duration, :total_duration,
                  :username, :status, :bytes_sent, :referer

    PATTERN = /\[(.*)\] (\S+) \"(.*)\" \"(.*)\" \"(.*)\" ([0-9]+) ([0-9]+) \"(.*)\" ([0-9.]+) ([0-9.]+) "(.*)"/

    TIME_FORMAT = "%d/%b/%Y:%H:%M:%S %Z"

    def self.parse(line)

      result = new
      _, result.time, result.ip_address, result.url, result.user_agent,
        result.route, result.status, result.bytes_sent, result.referer,
        result.rails_duration, result.total_duration, result.username = line.match(PATTERN).to_a

      result.rails_duration = result.rails_duration.to_f
      result.total_duration = result.total_duration.to_f

      verb = result.url[0..3] if result.url
      if verb && verb == "POST"
        result.route += " (POST)"
      end

      if verb && verb == "PUT"
        result.route += " (PUT)"
      end

      result
    end

    def is_mobile?
      user_agent =~ /Mobile|Android|webOS/ && !(user_agent =~ /iPad|Nexus (7|10)/)
    end

    def parsed_time
      DateTime.strptime(time, TIME_FORMAT) if time
    end
  end

  attr_reader :total_requests, :message_bus_requests, :filenames,
              :ip_to_rails_duration, :username_to_rails_duration,
              :route_to_rails_duration, :url_to_rails_duration,
              :status_404_to_count, :from_time, :to_time

  def self.analyze(filenames, args)
    new(filenames, args).analyze
  end

  class Aggeregator

    attr_accessor :aggregate_type

    def initialize
      @data = {}
      @aggregate_type = :duration
    end

    def add(id, duration, aggregate=nil)
      ary = (@data[id] ||= [0,0])
      ary[0] += duration
      ary[1] += 1
      unless aggregate.nil?
        ary[2] ||= Hash.new(0)
        if @aggregate_type == :duration
          ary[2][aggregate] += duration
        elsif @aggregate_type == :count
          ary[2][aggregate] += 1
        end
      end
    end

    def top(n, aggregator_formatter=nil)
      @data.sort{|a,b| b[1][0] <=> a[1][0]}.first(n).map do |metric, ary|
        metric = metric.to_s
        metric = "[empty]" if metric.length == 0
        result = [metric, ary[0], ary[1]]
        # handle aggregate
        if ary[2]
          if aggregator_formatter
            result.push aggregator_formatter.call(ary[2], ary[0], ary[1])
          else
            result.push ary[2].sort{|a,b| b[1] <=> a[1]}.first(5).map{|k,v|
            v = "%.2f" % v if Float === v
            "#{k}(#{v})"}.join(" ")
          end
        end

        result
      end
    end
  end

  def initialize(filenames, args={})
    @filenames = filenames
    @ip_to_rails_duration = Aggeregator.new
    @username_to_rails_duration = Aggeregator.new

    @route_to_rails_duration = Aggeregator.new
    @route_to_rails_duration.aggregate_type = :count

    @url_to_rails_duration = Aggeregator.new
    @status_404_to_count = Aggeregator.new

    @total_requests = 0
    @message_bus_requests = 0
    @limit = args[:limit]
  end

  def analyze
    now = DateTime.now

    @filenames.each do |filename|
      File.open(filename).each_line do |line|
        @total_requests += 1
        parsed = LineParser.parse(line)

        next unless parsed.time
        next if @limit && ((now - parsed.parsed_time) * 24 * 60).to_i > @limit

        @from_time ||= parsed.time
        @to_time = parsed.time

        if parsed.url =~ /(POST|GET) \/message-bus/
          @message_bus_requests += 1
          next
        end

        @ip_to_rails_duration.add(parsed.ip_address, parsed.rails_duration)

        username = parsed.username == "-" ? "[Anonymous]" : parsed.username
        @username_to_rails_duration.add(username, parsed.rails_duration, parsed.route)

        @route_to_rails_duration.add(parsed.route, parsed.rails_duration, parsed.is_mobile? ? "mobile" : "desktop")

        @url_to_rails_duration.add(parsed.url, parsed.rails_duration)

        @status_404_to_count.add(parsed.url,1) if parsed.status == "404"
      end
    end
    self
  end

end

args = ARGV.dup

if args[0] == "--limit"
  args.shift
  limit = args.shift.to_i
end

filenames = args if args[0]
filenames ||= ["/var/log/nginx/access.log", "/var/log/nginx/access.log.1"]

analyzer = LogAnalyzer.analyze(filenames, limit: limit)

SPACER = "-" * 100

# don't feel like pulling in active support
def map_with_index(ary, &block)
  idx = 0
  ary.map do |item|
    v = block.call(item, idx)
    idx += 1
    v
  end
end

def top(cols, aggregator, count, aggregator_formatter = nil)
  sorted = aggregator.top(count, aggregator_formatter)

  col_just = []

  col_widths = map_with_index(cols) do |name,idx|
    max_width = name.length

    if cols[idx].respond_to? :align
      col_just[idx] = cols[idx].align
      skip_just_detection = true
    else
      col_just[idx] = :ljust
    end

    sorted.each do |row|
      col_just[idx] = :rjust unless (String === row[idx] || row[idx].nil?) && !skip_just_detection
      row[idx] = '%.2f' % row[idx] if Float === row[idx]
      row[idx] = row[idx].to_s
      max_width = row[idx].length if row[idx].length > max_width
    end
    [max_width,80].min
  end

  puts(map_with_index(cols) do |name,idx|
    name.ljust(col_widths[idx])
  end.join(" "))

  puts(map_with_index(cols) do |name,idx|
    ("-" * name.length).ljust(col_widths[idx])
  end.join(" "))

  sorted.each do |raw_row|

    rows = []
    idx = 0
    raw_row.each do |col|
      j = 0
      col.to_s.scan(/(.{1,80}($|\s)|.{1,80})/).each do |r|
        rows[j] ||= []
        rows[j][idx] = r[0]
        j += 1
      end
      idx += 1
    end

    if rows.length > 1
      puts
    end

    rows.each do |row|
      cols.length.times do |i|
        print row[i].to_s.send(col_just[i], col_widths[i])
        print " "
      end
      puts
    end

    if rows.length > 1
      puts
    end

  end
end

class Column < String
  attr_accessor :align

  def initialize(val, align)
    super(val)
    @align = align
  end
end

puts
puts "Analyzed: #{analyzer.filenames.join(",")} on #{`hostname`}"
if limit
  puts "Limited to #{DateTime.now - (limit.to_f / (60*24.0))} - #{DateTime.now}"
end
puts SPACER
puts "#{analyzer.from_time} - #{analyzer.to_time}"
puts SPACER
puts "Total Requests: #{analyzer.total_requests} ( MessageBus: #{analyzer.message_bus_requests} )"
puts SPACER
puts "Top 30 IPs by Server Load"
puts
top(["IP Address", "Duration", "Reqs"], analyzer.ip_to_rails_duration, 30)
puts SPACER
puts
puts "Top 30 users by Server Load"
puts
top(["Username", "Duration", "Reqs", "Routes"], analyzer.username_to_rails_duration, 30)
puts SPACER
puts
puts "Top 100 routes by Server Load"
puts
top(["Route", "Duration", "Reqs", Column.new("Mobile", :rjust)], analyzer.route_to_rails_duration, 100, lambda{
  |hash, name, total|
  "#{hash["mobile"] || 0} (#{"%.2f" % (((hash["mobile"] || 0) / (total + 0.0)) * 100)})%"}
)
puts SPACER
puts
puts "Top 30 urls by Server Load"
puts
top(["Url", "Duration", "Reqs"], analyzer.url_to_rails_duration, 30)

puts "(all durations in seconds)"
puts SPACER
puts
puts "Top 30 not found urls (404s)"
puts
top(["Url", "Count"], analyzer.status_404_to_count, 30)
