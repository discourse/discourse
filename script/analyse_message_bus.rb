# frozen_string_literal: true

require File.expand_path("../../config/environment", __FILE__)

channel_counters = Hash.new(0)
messages_seen = 0

wait_seconds = ARGV[0]&.to_i || 10

puts "Counting messages for #{wait_seconds} seconds..."

print "Seen 0 messages"
t =
  Thread.new do
    MessageBus.backend_instance.global_subscribe do |m|
      channel = m.channel
      if channel.start_with?("/distributed_hash")
        payload = JSON.parse(m.data)["data"]
        info = payload["hash_key"]
        # info += ".#{payload["key"]}" # Uncomment if you need more granular info
        channel += " (#{info})"
      end

      channel_counters[channel] += 1
      messages_seen += 1

      print "\rSeen #{messages_seen} messages from #{channel_counters.size} channels"
    end
  end

sleep wait_seconds

MessageBus.backend_instance.global_unsubscribe
t.join

puts
puts "All done!"

if messages_seen == 0
  puts "Saw no messages :("
  exit 1
end

puts
puts
sorted_results = channel_counters.sort_by { |k, v| -v }
max_channel_name_length = channel_counters.keys.max_by { |name| name.length }.length
max_count_length = channel_counters.values.max_by { |val| val.to_s.length }.to_s.length

max_channel_name_length = ["channel".length, max_channel_name_length].max
max_count_length = ["message count".length, max_count_length, messages_seen.to_s.length].max

puts "| #{"channel".ljust(max_channel_name_length)} | #{"message count".rjust(max_count_length)} |"
puts "|#{"-" * (max_channel_name_length + 2)}|#{"-" * (max_count_length + 2)}|"

result_count = 10
sorted_results
  .first(result_count)
  .each do |name, value|
    name = "`#{name}`"
    puts "| #{name.ljust(max_channel_name_length)} | #{value.to_s.rjust(max_count_length)} |"
  end
other_count = messages_seen - sorted_results.first(result_count).sum { |k, v| v }
puts "| #{"(other)".ljust(max_channel_name_length)} | #{other_count.to_s.rjust(max_count_length)} |"
puts "|#{" " * (max_channel_name_length + 2)}|#{" " * (max_count_length + 2)}|"
puts "| #{"TOTAL".ljust(max_channel_name_length)} | #{messages_seen.to_s.rjust(max_count_length)} |"
