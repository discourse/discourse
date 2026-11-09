# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryResultCache
    class Key < Data.define(:query_id, :visibility, :digest)
      class Invalid < ArgumentError
      end

      FORMAT = /\A(?<query_id>-?\d+):(?<visibility>admin|-?\d+):(?<digest>[a-f0-9]{64})\z/
      private_constant :FORMAT

      class << self
        def for(query_id, user, params_hash)
          new(
            query_id: query_id.to_s,
            visibility: QueryResultCache.visibility_scope(user).to_s,
            digest: Digest::SHA256.hexdigest((params_hash || {}).sort.to_h.to_json),
          )
        end

        def parse(id)
          match = FORMAT.match(id.to_s) or raise Invalid, "Invalid cached-result ID."
          new(**match.named_captures.symbolize_keys)
        end
      end

      def id = "#{query_id}:#{visibility}:#{digest}"

      def to_s = "data_explorer:result:#{id}"

      def visible_to?(user) = visibility == QueryResultCache.visibility_scope(user).to_s
    end
  end
end
