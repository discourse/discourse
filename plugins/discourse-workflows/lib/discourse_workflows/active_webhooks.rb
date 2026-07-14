# frozen_string_literal: true

module DiscourseWorkflows
  class ActiveWebhooks
    VERSION_KEY = "version"

    class << self
      def cache
        @cache ||= DistributedCache.new("discourse_workflows_active_webhooks")
      end

      def invalidate!
        cache.delete(VERSION_KEY)
        @snapshot = nil
        @snapshot_version = nil
      end

      def find(method:, path:, test_webhook: false)
        snapshot.find(method: method, path: path, test_webhook: test_webhook)
      end

      def reset_for_tests!
        @cache = nil
        @snapshot = nil
        @snapshot_version = nil
      end

      private

      def snapshot
        current_version = cache.defer_get_set(VERSION_KEY) { SecureRandom.uuid }
        if @snapshot.nil? || @snapshot_version != current_version
          @snapshot = Snapshot.new(Webhook.live.to_a)
          @snapshot_version = current_version
        end
        @snapshot
      end
    end

    class Snapshot
      def initialize(webhooks)
        @static = Hash.new
        @dynamic = Hash.new { |h, k| h[k] = [] }
        @test_static = Hash.new
        @test_dynamic = Hash.new { |h, k| h[k] = [] }

        webhooks.each { |webhook| add(webhook) }

        @dynamic.each_value { |list| list.sort_by!(&:path_length).reverse! }
        @test_dynamic.each_value { |list| list.sort_by!(&:path_length).reverse! }
      end

      def find(method:, path:, test_webhook:)
        http_method = Webhook.normalize_method(method)
        normalized_path = Webhook.normalize_path(path)

        static_map = test_webhook ? @test_static : @static
        if (static_webhook = static_map[[http_method, normalized_path]])
          return { webhook: static_webhook, path_params: {} }
        end

        segments = Webhook.segments_for(normalized_path)
        return nil if segments.empty?

        dynamic_map = test_webhook ? @test_dynamic : @dynamic
        candidate_id = segments.first
        remaining = segments[1..]

        dynamic_map[[http_method, candidate_id]].each do |dynamic_webhook|
          params =
            Webhook.match_dynamic_path(template: dynamic_webhook.webhook_path, segments: remaining)
          return { webhook: dynamic_webhook, path_params: params } if params
        end

        nil
      end

      private

      def add(webhook)
        if webhook.dynamic?
          target = webhook.test_webhook? ? @test_dynamic : @dynamic
          target[[webhook.http_method, webhook.webhook_id]] << webhook
        else
          target = webhook.test_webhook? ? @test_static : @static
          target[[webhook.http_method, webhook.webhook_path]] = webhook
        end
      end
    end
  end
end
