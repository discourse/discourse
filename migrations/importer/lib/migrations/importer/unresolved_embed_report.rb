# frozen_string_literal: true

module Migrations
  module Importer
    # Takes the embeds {PlaceholderResolver} could not resolve and writes them to
    # the mappings database. A run can have a lot of them, so they go to disk
    # instead of piling up in memory; the connection commits them in batches.
    # Only the counts per kind are kept, for the step's summary.
    class UnresolvedEmbedReport
      INSERT_SQL = <<~SQL
        INSERT INTO mapped.unresolved_embeds (kind, entity_id, owner_id, owner_url)
        VALUES (?, ?, ?, ?)
      SQL
      private_constant :INSERT_SQL

      # FIXME: polls and events have no converter and importer steps yet, so
      # every one of them would end up here and drown out the real misses.
      # Remove this once those steps exist.
      EXCLUDED_KINDS = %i[poll event].freeze
      private_constant :EXCLUDED_KINDS

      attr_reader :counts_by_kind

      def initialize(intermediate_db)
        @intermediate_db = intermediate_db
        @counts_by_kind = Hash.new(0)
      end

      def <<(embed)
        return self if EXCLUDED_KINDS.include?(embed.kind)

        @counts_by_kind[embed.kind] += 1
        @intermediate_db.insert(
          INSERT_SQL,
          [embed.kind.to_s, embed.entity_id&.to_s, embed.owner_id, embed.owner_url],
        )

        self
      end
    end
  end
end
