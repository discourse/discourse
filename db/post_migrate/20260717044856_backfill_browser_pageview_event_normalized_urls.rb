# frozen_string_literal: true

class BackfillBrowserPageviewEventNormalizedUrls < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 1000
  MAX_LENGTH = 2000

  def up
    last_id = 0
    cutoff = 29.days.ago.utc.beginning_of_day

    loop do
      rows = DB.query(<<~SQL, last_id:, cutoff:, batch_size: BATCH_SIZE)
          SELECT id, url
          FROM browser_pageview_events
          WHERE id > :last_id
            AND created_at >= :cutoff
            AND normalized_url IS NULL
          ORDER BY id
          LIMIT :batch_size
        SQL
      break if rows.empty?

      last_id = rows.last.id
      update_rows(rows)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def update_rows(rows)
    values =
      rows.filter_map do |row|
        normalized_url = normalize(row.url)
        next if normalized_url.nil?

        "(#{row.id.to_i}, #{connection.quote(normalized_url)})"
      end
    return if values.empty?

    execute <<~SQL
      UPDATE browser_pageview_events AS events
      SET normalized_url = normalized.normalized_url
      FROM (VALUES #{values.join(", ")}) AS normalized(id, normalized_url)
      WHERE events.id = normalized.id
    SQL
  end

  def normalize(raw_url)
    return nil if raw_url.blank?

    value = raw_url.to_s.strip
    return nil if value.match?(/[[:space:][:cntrl:]]/) || value.match?(/%(?![0-9a-f]{2})/i)

    uri = Addressable::URI.parse(value)
    return nil unless valid_uri?(uri)

    path = uri.path.to_s.sub(%r{/+\z}, "")
    path = "/" if path.empty?
    path.byteslice(0, MAX_LENGTH).scrub("")
  rescue Addressable::URI::InvalidURIError, ArgumentError, TypeError
    nil
  end

  def valid_uri?(uri)
    return false if uri.nil?

    if uri.scheme.present?
      %w[http https].include?(uri.scheme.downcase) && uri.host.present?
    else
      uri.host.blank? && uri.path.to_s.start_with?("/")
    end
  end
end
