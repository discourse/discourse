# frozen_string_literal: true

require_relative "content_policy"

module BulkImport::DiscourseMerge
  # COPY and independent verification read the same reviewed source rows in
  # bounded batches. Raw PostgreSQL keeps credentials out of Rails' SQL logs.
  class ContentTransfer
    def initialize(source, destination, maps, category_keys, references, ids)
      @source, @destination, @references, @ids = source, destination, references, ids
      @maps = maps.stringify_keys.merge("category_keys" => category_keys).merge(ids)
      @encoder = PG::TextEncoder::CopyRow.new
    end

    def copy(decisions)
      raise Error, "Unknown content table" unless (decisions.keys - ContentPolicy::TABLES).empty?
      ContentPolicy::TABLES.each do |table|
        rows = decisions.fetch(table, [])
        next if rows.empty?
        klass = model(table)
        table_ids = @ids[table] = @maps[table] = {}
        last = klass.unscoped.maximum(:id).to_i
        columns = klass.column_names
        quoted = columns.map { |column| PG::Connection.quote_ident(column) }.join(",")
        each_copy_batch(table, rows) do |batch, source|
          @destination.copy_data("COPY #{table} (#{quoted}) FROM STDIN", @encoder) do
            batch.each do |r|
              id = r.fetch("id")
              attrs = attributes(table, r, source.fetch(id))
              table_ids[id] = attrs["id"] = (last += 1)
              @destination.put_copy_data(attrs.values_at(*columns))
            end
          end
        end
        rows
          .select { |row| row["action"] == "reused" }
          .each do |row|
            table_ids[row.fetch("id")] = row.fetch("target") do
              table_ids.fetch(row.fetch("source_target"))
            end
          end
        klass.connection.reset_pk_sequence!(table) if rows.any? { |r| r["action"] == "copied" }
      rescue PG::Error
        raise unless table == "user_passwords"
        raise Error, "Failed to copy local password records", cause: nil
      end
      Emoji.clear_cache if decisions.fetch("custom_emojis", []).any? { |r| r["action"] == "copied" }
    end

    def verify(decisions)
      decisions.each do |table, rows|
        klass = model(table)
        ids = @ids.fetch(table, {})
        retained = rows.reject { |r| r["action"] == "skipped" }
        copied_ids = rows.filter_map { |row| ids[row.fetch("id")] if row["action"] == "copied" }
        unless ids.keys.to_set == retained.pluck("id").to_set &&
                 copied_ids.uniq.size == copied_ids.size
          raise Error, "Incomplete reviewed mappings for #{table}"
        end
        retained
          .select { |r| r["action"] == "reused" }
          .each_slice(1000) do |batch|
            targets =
              batch.map { |row| row.fetch("target") { ids.fetch(row.fetch("source_target")) } }
            found = load_rows(@destination, table, targets)
            unless batch
                     .zip(targets)
                     .all? { |row, target| ids.fetch(row["id"]) == target && found.key?(target) }
              raise Error, "Reviewed destination record differs in #{table}"
            end
          end
        each_copy_batch(table, rows) do |batch, source|
          actual = load_rows(@destination, table, batch.map { |r| ids.fetch(r.fetch("id")) })
          batch.each do |r|
            id = r.fetch("id")
            expected = attributes(table, r, source.fetch(id))
            record = actual.fetch(ids.fetch(id))
            klass
              .column_names
              .excluding("id")
              .each do |col|
                type = klass.type_for_attribute(col)
                unless type.deserialize(record[col]) == type.deserialize(expected[col])
                  raise Error, "Reviewed #{table} row #{id} differs in #{col}"
                end
              end
          end
        end
      end
      withheld = decisions.fetch("user_passwords", []).filter_map { |row| row["without_password"] }
      withheld.each_slice(1000) do |batch|
        accounts = batch.map { |id| @maps.fetch("users").fetch(id) }
        if UserPassword.exists?(user_id: accounts)
          raise Error, "A withheld local password was installed"
        end
      end
      verify_media_references(decisions)
      ContentPolicy.summary(decisions)
    end

    private

    def verify_media_references(decisions)
      %w[custom_emojis post_localizations].each do |table|
        type = table.classify
        targets = @ids.fetch(table, {})
        decisions
          .fetch(table, [])
          .select { |row| row["action"] == "copied" }
          .each_slice(1000) do |batch|
            originals = batch.pluck("id")
            expected = Hash.new { |h, k| h[k] = Set.new }
            @source
              .exec_params(
                "SELECT target_id,upload_id FROM upload_references WHERE target_type=$1 AND target_id=ANY($2::bigint[])",
                [type, PG::TextEncoder::Array.new.encode(originals)],
              )
              .each do |ref|
                expected[targets.fetch(ref.fetch("target_id").to_i)] << @maps.fetch(
                  "uploads",
                ).fetch(ref.fetch("upload_id").to_i)
              end
            if table == "custom_emojis"
              batch.each do |row|
                upload = row.fetch("refs").fetch("upload_id").last
                expected[targets.fetch(row.fetch("id"))] << @maps.fetch("uploads").fetch(upload)
              end
            end
            actual =
              UploadReference
                .where(target_type: type, target_id: originals.map { |id| targets.fetch(id) })
                .pluck(:target_id, :upload_id)
                .group_by(&:first)
                .transform_values { |pairs| pairs.to_set(&:last) }
            raise Error, "Incomplete #{type} upload references" unless actual == expected
          end
      end
    end

    def model(table)
      raise Error, "Unknown content table" if ContentPolicy::TABLES.exclude?(table)
      table.classify.constantize
    end

    def load_rows(connection, table, ids)
      connection
        .exec("SELECT * FROM #{table} WHERE id IN (#{ids.map { |id| Integer(id) }.join(",")})")
        .index_by { |r| r.fetch("id").to_i }
    end

    def each_copy_batch(table, rows)
      rows
        .select { |r| r["action"] == "copied" }
        .each_slice(1000) { |batch| yield batch, load_rows(@source, table, batch.pluck("id")) }
    end

    def attributes(table, decision, source)
      attrs = source.merge(decision.fetch("values", {}))
      decision
        .fetch("refs", {})
        .each do |col, (map, original)|
          value = @maps.fetch(map).fetch(original)
          attrs[col] = (
            if table == "user_custom_fields" && col == "name"
              "user_field_#{value}"
            else
              value
            end
          )
        end
      case table
      when "post_localizations"
        attrs["raw"] = @references.rewrite(attrs.fetch("raw"))
        attrs["cooked"] = @references.rewrite(attrs.fetch("cooked"), cooked: true)
      when "category_localizations", "tag_localizations", "topic_localizations"
        %w[description description_cooked excerpt].each do |col|
          attrs[col] = @references.rewrite(attrs[col], cooked: col != "description") if attrs[col]
        end
      end
      attrs
    end
  end
end
