require 'date'
require_relative '../lib/log_analyzer'

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

  col_widths = map_with_index(cols) do |name, idx|
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
    [max_width, 80].min
  end

  puts(map_with_index(cols) do |name, idx|
    name.ljust(col_widths[idx])
  end.join(" "))

  puts(map_with_index(cols) do |name, idx|
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
  puts "Limited to #{DateTime.now - (limit.to_f / (60 * 24.0))} - #{DateTime.now}"
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
top(["Route", "Duration", "Reqs", Column.new("Mobile", :rjust)], analyzer.route_to_rails_duration, 100, lambda {
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
