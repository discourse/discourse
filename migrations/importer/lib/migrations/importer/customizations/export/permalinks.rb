# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Export
        class Permalinks
          def initialize(matcher)
            @matcher = matcher
          end

          def call(item)
            entry = item.slice("url", "target", "note")
            # Plan urls are stored values; `find_by_url` would normalize them again.
            permalink = ::Permalink.find_by(url: item["url"])
            return entry.merge("remove" => true) if item["remove"] || permalink.nil?

            entry.merge(reference(permalink))
          end

          private

          def reference(permalink)
            return { "external_url" => permalink.external_url } if permalink.external_url.present?

            if permalink.topic_id
              { "topic" => @matcher.keys_for(:topic, existing(permalink.topic, :topic, permalink)) }
            elsif permalink.post_id
              post = existing(permalink.post, :post, permalink)
              topic = post.topic
              raise Error, "topic #{post.topic_id} does not exist" if topic.nil?
              {
                "post" =>
                  @matcher.keys_for(:post, post).merge("topic" => @matcher.keys_for(:topic, topic)),
              }
            elsif permalink.category_id
              category = existing(permalink.category, :category, permalink)
              { "category" => @matcher.keys_for(:category, category) }
            elsif permalink.tag_id
              { "tag" => @matcher.keys_for(:tag, existing(permalink.tag, :tag, permalink)) }
            elsif permalink.user_id
              { "user" => @matcher.keys_for(:user, existing(permalink.user, :user, permalink)) }
            else
              raise Error, "has no target"
            end
          end

          def existing(record, kind, permalink)
            raise Error, "#{kind} #{permalink["#{kind}_id"]} does not exist" if record.nil?
            record
          end
        end
      end
    end
  end
end
