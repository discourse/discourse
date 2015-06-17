class LogAnalyzer

  class LineParser


    # log_format log_discourse '[$time_local] $remote_addr "$request" "$http_user_agent" "$sent_http_x_discourse_route" $status $bytes_sent "$http_referer" $upstream_response_time $request_time "$sent_http_x_discourse_username"';

    attr_accessor :time, :ip_address, :url, :route, :user_agent, :rails_duration, :total_duration,
                  :username, :status, :bytes_sent, :referer

    PATTERN = /\[(.*)\] (\S+) \"(.*)\" \"(.*)\" \"(.*)\" ([0-9]+) ([0-9]+) \"(.*)\" ([0-9.]+) ([0-9.]+) "(.*)"/

    def self.parse(line)
      result = new
      _, result.time, result.ip_address, result.url, result.user_agent,
        result.route, result.status, result.bytes_sent, result.referer,
        result.rails_duration, result.total_duration, result.username = line.match(PATTERN).to_a

      result.rails_duration = result.rails_duration.to_f
      result.total_duration = result.total_duration.to_f

      result
    end
  end

  attr_reader :total_requests, :message_bus_requests, :filename,
              :ip_to_rails_duration, :username_to_rails_duration,
              :route_to_rails_duration, :url_to_rails_duration,
              :status_404_to_count

  def self.analyze(filename)
    new(filename).analyze
  end

  def initialize(filename)
    @filename = filename
    @ip_to_rails_duration = Hash.new(0)
    @username_to_rails_duration = Hash.new(0)
    @route_to_rails_duration = Hash.new(0)
    @url_to_rails_duration = Hash.new(0)
    @status_404_to_count = Hash.new(0)
  end

  def analyze
    @total_requests = 0
    @message_bus_requests = 0
    File.open(@filename).each_line do |line|
      @total_requests += 1
      parsed = LineParser.parse(line)

      if parsed.url =~ /(POST|GET) \/message-bus/
        @message_bus_requests += 1
        next
      end

      @ip_to_rails_duration[parsed.ip_address] += parsed.rails_duration

      username = parsed.username == "-" ? "[Anonymous]" : parsed.username
      @username_to_rails_duration[username] += parsed.rails_duration

      @route_to_rails_duration[parsed.route] += parsed.rails_duration

      @url_to_rails_duration[parsed.url] += parsed.rails_duration

      @status_404_to_count[parsed.url] += 1 if parsed.status == "404"
    end
    self
  end

end

filename = ARGV[0] || "/var/log/nginx/access.log"
analyzer = LogAnalyzer.analyze(filename)

SPACER = "-" * 80

def top(cols, hash, count)
  sorted = hash.sort{|a,b| b[1] <=> a[1]}.first(30)

  longest_0 = [cols[0].length, sorted.map{|a,b| a.to_s.length}.max ].max

  puts "#{cols[0].ljust(longest_0)} #{cols[1]}"
  puts "#{("-"*(cols[0].length)).ljust(longest_0)} #{"-"*cols[1].length}"

  sorted.each do |val, duration|
    next unless val && val.length > 1
    n = Fixnum === duration ? duration : '%.2f' % duration
    puts "#{val.to_s.ljust(longest_0)} #{n.to_s.rjust(cols[1].length)}"
  end
end

puts
puts "Analyzed: #{analyzer.filename}"
puts SPACER
puts "Total Requests: #{analyzer.total_requests} ( MessageBus: #{analyzer.message_bus_requests} )"
puts SPACER
puts "Top 30 IPs by Server Load"
puts
top(["IP Address", "Duration"], analyzer.ip_to_rails_duration, 30)
puts SPACER
puts
puts "Top 30 users by Server Load"
puts
top(["Username", "Duration"], analyzer.username_to_rails_duration, 30)
puts SPACER
puts
puts "Top 30 routes by Server Load"
puts
top(["Route", "Duration"], analyzer.route_to_rails_duration, 30)
puts SPACER
puts
puts "Top 30 urls by Server Load"
puts
top(["Url", "Duration"], analyzer.url_to_rails_duration, 30)

puts "(all durations in seconds)"
puts SPACER
puts
puts "Top 30 not found urls (404s)"
puts
top(["Url", "Count"], analyzer.status_404_to_count, 30)
