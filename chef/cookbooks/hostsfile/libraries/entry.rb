#
# Author:: Seth Vargo <sethvargo@gmail.com>
# Cookbook:: hostsfile
# Library:: entry
#
# Copyright 2012-2013, Seth Vargo
# Copyright 2012, CustomInk, LCC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'ipaddr'

# An object representation of a single line in a hostsfile.
#
# @author Seth Vargo <sethvargo@gmail.com>
class Entry
  class << self
    # Creates a new Hostsfile::Entry object by parsing a text line. The
    # `line` attribute will be in the following format:
    #
    #     1.2.3.4 hostname [alias[, alias[, alias]]] [# comment [@priority]]
    #
    # @param [String] line
    #   the line to parse
    # @return [Entry]
    #   a new entry object
    def parse(line)
      entry, comment = extract_comment(line)
      comment, priority = extract_priority(comment)
      entries = extract_entries(entry)

      # Return nil if the line is empty
      return nil if entries.nil? || entries.empty?

      return self.new(
        ip_address: entries[0],
        hostname:   entries[1],
        aliases:    entries[2..-1],
        comment:    comment,
        priority:   priority,
      )
    end

    private
      def extract_comment(line)
        return nil if presence(line).nil?
        line.split('#', 2).collect { |part| presence(part) }
      end

      def extract_priority(comment)
        return nil if comment.nil?

        if comment.include?('@')
          comment.split('@', 2).collect { |part| presence(part) }
        else
          [comment, nil]
        end
      end

      def extract_entries(entry)
        return nil if entry.nil?
        entry.split(/\s+/).collect { |entry| presence(entry) }.compact
      end

      def presence(string)
        return nil if string.nil?
        return nil if string.strip.empty?
        string.strip
      end
  end

  # @return [String]
  attr_accessor :ip_address, :hostname, :aliases, :comment, :priority

  # Creates a new entry from the given options.
  #
  # @param [Hash] options
  #   a list of options to create the entry with
  # @option options [String] :ip_address
  #   the IP Address for this entry
  # @option options [String] :hostname
  #   the hostname for this entry
  # @option options [String, Array<String>] :aliases
  #   a alias or array of aliases for this entry
  # @option options[String] :comment
  #   an optional comment for this entry
  # @option options [Fixnum] :priority
  #   the relative priority of this entry (compared to others)
  #
  # @raise [ArgumentError]
  #   if neither :ip_address nor :hostname are supplied
  def initialize(options = {})
    if options[:ip_address].nil? || options[:hostname].nil?
      raise ArgumentError, ':ip_address and :hostname are both required options'
    end

    @ip_address = IPAddr.new(options[:ip_address].to_s)
    @hostname   = options[:hostname]
    @aliases    = [options[:aliases]].flatten.compact
    @comment    = options[:comment]
    @priority   = options[:priority] || calculated_priority
  end

  # Set a the new priority for an entry.
  #
  # @param [Fixnum] new_priority
  #   the new priority to set
  def priority=(new_priority)
    @calculated_priority = false
    @priority = new_priority
  end

  # The line representation of this entry.
  #
  # @return [String]
  #   the string representation of this entry
  def to_line
    hosts = [hostname, aliases].flatten.join(' ')

    comments = "# #{comment.to_s}".strip
    comments << " @#{priority}" unless priority.nil? || @calculated_priority
    comments = comments.strip
    comments = nil if comments == '#'

    [ip_address, hosts, comments].compact.join("\t").strip
  end

  # The string representation of this Entry
  #
  # @return [String]
  #   the string representation of this entry
  def to_s
    "#<#{self.class.to_s} " + [
      "ip_address: '#{ip_address}'",
      "hostname: '#{hostname}'",
    ].join(', ') + '>'
  end

  # The object representation of this Entry
  #
  # @return [String]
  #   the object representation of this entry
  def inspect
    "#<#{self.class.to_s} " + [
      "ip_address: '#{ip_address}'",
      "hostname: '#{hostname}'",
      "aliases: #{aliases.inspect}",
      "comment: '#{comment}'",
      "priority: #{priority}",
      "calculated_priority?: #{@calculated_priority}",
    ].join(', ') + '>'
  end

  # Returns true if priority is calculated
  #
  # @return [Boolean]
  #   true if priority is calculated and false otherwise
  def calculated_priority?
    @calculated_priority
  end

  private

    # Calculates the relative priority of this entry.
    #
    # @return [Fixnum]
    #   the relative priority of this item
    def calculated_priority
      @calculated_priority = true

      return 81 if ip_address == IPAddr.new('127.0.0.1')
      return 80 if IPAddr.new('127.0.0.0/8').include?(ip_address) # local
      return 60 if ip_address.ipv4? # ipv4
      return 20 if ip_address.ipv6? # ipv6
      return 00
    end
end
