# frozen_string_literal: true

require "resolv"

module DiscourseAi
  module Utils
    module DnsSrv
      def self.lookup(domain)
        Discourse
          .cache
          .fetch("dns_srv_lookup:#{domain}", expires_in: 5.minutes) do
            resources = dns_srv_lookup_for_domain(domain)

            server_election(resources)
          end
      end

      private

      def self.dns_srv_lookup_for_domain(domain)
        resolver = Resolv::DNS.new
        resolver.getresources(domain, Resolv::DNS::Resource::IN::SRV)
      end

      def self.select_server(resources)
        priority = resources.group_by(&:priority).keys.min

        priority_resources = resources.select { |r| r.priority == priority }

        total_weight = priority_resources.map(&:weight).sum

        random_weight = rand(total_weight)

        priority_resources.each do |resource|
          random_weight -= resource.weight

          return resource if random_weight < 0
        end
      end

      def self.server_available?(server)
        begin
          conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
          conn.head("https://#{server.target}:#{server.port}")
          true
        rescue StandardError
          false
        end
      end

      def self.server_election(resources)
        return nil if resources.empty?
        return resources.first if resources.length == 1

        candidate = select_server(resources)

        if server_available?(candidate)
          candidate
        else
          server_election(resources - [candidate])
        end
      end
    end
  end
end
