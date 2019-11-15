#!/usr/bin/env ruby
# frozen_string_literal: true

# from: https://gist.github.com/kenn/5105061/raw/ac7ebc6be7008c35b72560cc4e05b7cc14eb4919/memstats.rb

#------------------------------------------------------------------------------
# Aggregate Print useful information from /proc/[pid]/smaps
#
# pss  - Roughly the amount of memory that is "really" being used by the pid
# swap - Amount of swap this process is currently using
#
# Reference:
#  http://www.mjmwired.net/kernel/Documentation/filesystems/proc.txt#361
#
# Example:
#   # ./memstats.rb 4386
#   Process:             4386
#   Command Line:        /usr/bin/mongod -f /etc/mongo/mongod.conf
#   Memory Summary:
#     private_clean             107,132 kB
#     private_dirty           2,020,676 kB
#     pss                     2,127,860 kB
#     rss                     2,128,536 kB
#     shared_clean                  728 kB
#     shared_dirty                    0 kB
#     size                  149,281,668 kB
#     swap                    1,719,792 kB
#------------------------------------------------------------------------------

class Mapping
  FIELDS = %w[ size rss shared_clean shared_dirty private_clean private_dirty swap pss ]
  attr_reader :address_start
  attr_reader :address_end
  attr_reader :perms
  attr_reader :offset
  attr_reader :device_major
  attr_reader :device_minor
  attr_reader :inode
  attr_reader :region

  attr_accessor :size
  attr_accessor :rss
  attr_accessor :shared_clean
  attr_accessor :shared_dirty
  attr_accessor :private_dirty
  attr_accessor :private_clean
  attr_accessor :swap
  attr_accessor :pss

  def initialize(lines)

    FIELDS.each do |field|
      self.public_send("#{field}=", 0)
    end

    parse_first_line(lines.shift)
    lines.each do |l|
      parse_field_line(l)
    end
  end

  def parse_first_line(line)
    parts = line.strip.split
    @address_start, @address_end = parts[0].split("-")
    @perms = parts[1]
    @offset = parts[2]
    @device_major, @device_minor = parts[3].split(":")
    @inode = parts[4]
    @region = parts[5] || "anonymous"
  end

  def parse_field_line(line)
    parts = line.strip.split
    field = parts[0].downcase.sub(':', '')
    if respond_to? "#{field}="
      value = Float(parts[1]).to_i
      self.public_send("#{field}=", value)
    end
  end
end

def consume_mapping(map_lines, totals)
  m = Mapping.new(map_lines)

  Mapping::FIELDS.each do |field|
    totals[field] += m.public_send(field)
  end
  m
end

def create_memstats_not_available(totals)
  Mapping::FIELDS.each do |field|
    totals[field] += Float::NAN
  end
end

abort 'usage: memstats [pid]' unless ARGV.first
pid = ARGV.shift.to_i
totals = Hash.new(0)
mappings = []

begin
  File.open("/proc/#{pid}/smaps") do |smaps|

    map_lines = []

    loop do
      break if smaps.eof?
      line = smaps.readline.strip
      case line
      when /\w+:\s+/
        map_lines << line
      when /[0-9a-f]+:[0-9a-f]+\s+/
        if map_lines.size > 0 then
          mappings << consume_mapping(map_lines, totals)
        end
        map_lines.clear
        map_lines << line
      else
        break
      end
    end
  end
rescue
  create_memstats_not_available(totals)
end

# http://rubyforge.org/snippet/download.php?type=snippet&id=511
def format_number(n)
  n.to_s.gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/, '\1,\2')
end

def get_commandline(pid)
  commandline = IO.read("/proc/#{pid}/cmdline").split("\0")
  if commandline.first =~ /java$/ then
    loop { break if commandline.shift == "-jar" }
    return "[java] #{commandline.shift}"
  end
  commandline.join(' ')
end

if ARGV.include? '--yaml'
  require 'yaml'
  puts Hash[*totals.map do |k, v|
    [k + '_kb', v]
  end.flatten].to_yaml
else
  puts "#{"Process:".ljust(20)} #{pid}"
  puts "#{"Command Line:".ljust(20)} #{get_commandline(pid)}"
  puts "Memory Summary:"
  totals.keys.sort.each do |k|
    puts "  #{k.ljust(20)} #{format_number(totals[k]).rjust(12)} kB"
  end
end
