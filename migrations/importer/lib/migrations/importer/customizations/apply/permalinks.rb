# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        class Permalinks
          RECORD_MODELS = { "topic" => "Topic", "tag" => "Tag", "user" => "User" }.freeze

          def initialize(matcher, lookup, target:, dry_run:)
            @matcher = matcher
            @lookup = lookup
            @target = target
            @dry_run = dry_run
          end

          def call(entry)
            url = entry["url"].to_s
            raise Error, "url is missing" if url.empty?
            current = ::Permalink.find_by(url:)

            if entry["remove"]
              return :unchanged if current.nil?
              current.destroy! unless @dry_run
              return :changed
            end

            attributes, matched = resolve(entry)
            desired = Plan::Rules::PERMALINK_TARGET_COLUMNS.index_with { nil }.merge(attributes)

            if current
              return :unchanged, matched if current.slice(*desired.keys) == desired
              current.update_columns(desired) unless @dry_run
              return :changed, matched
            end

            # The url is stored already normalized and encoded; the model's
            # callbacks would encode it a second time ("%20" becomes "%2520").
            ::Permalink.new(desired.merge("url" => url)).save!(validate: false) unless @dry_run
            [:changed, matched ? "created, #{matched}" : "created"]
          end

          private

          # @return [Array(Hash, String)] target column and how it was matched
          def resolve(entry)
            if entry["external_url"].present?
              [{ "external_url" => entry["external_url"] }, nil]
            elsif entry["category"]
              category(entry["category"])
            elsif entry["post"]
              post(entry["post"])
            elsif (kind = RECORD_MODELS.keys.find { |k| entry[k] })
              record(kind, entry[kind])
            else
              raise Error, "has no target"
            end
          end

          def category(keys)
            match = @matcher.resolve(:category, keys) { |id| ::Category.exists?(id:) }
            return { "category_id" => match.id }, "matched by #{match.strategy}" if match

            if @target == "migrated"
              raise SkipItem, "no matching category found (tried #{keys.keys.join(", ")})"
            end
            [{ "category_id" => @lookup.category_id(keys) }, nil]
          end

          def record(kind, keys)
            model = RECORD_MODELS.fetch(kind).constantize
            match = @matcher.resolve(kind.to_sym, keys) { |id| model.exists?(id:) }
            if match.nil?
              raise SkipItem, "no matching #{kind} found (tried #{keys.keys.join(", ")})"
            end

            [{ "#{kind}_id" => match.id }, "matched by #{match.strategy}"]
          end

          # Post numbers are only unique within a topic, so they need the topic
          # resolved first, which a matcher strategy can't do.
          def post(keys)
            match = @matcher.resolve(:post, keys) { |id| ::Post.exists?(id:) }
            return { "post_id" => match.id }, "matched by #{match.strategy}" if match

            topic_keys = keys["topic"] || {}
            post_number = keys["post_number"]
            if post_number.present?
              topic = @matcher.resolve(:topic, topic_keys) { |id| ::Topic.exists?(id:) }
              post_id = topic && ::Post.where(topic_id: topic.id, post_number:).pick(:id)
              return { "post_id" => post_id }, "matched by topic and post_number" if post_id
            end

            tried = keys.keys - %w[topic post_number]
            if post_number.present?
              tried << "post_number in topic (by #{topic_keys.keys.join(", ")})"
            end
            raise SkipItem, "no matching post found (tried #{tried.join(", ")})"
          end
        end
      end
    end
  end
end
