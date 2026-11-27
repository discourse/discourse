# frozen_string_literal: true

class BackfillBeaconBrowserPageviewCounters < ActiveRecord::Migration[8.1]
  def up
    backfill_cohort(beacon_type: 17, piggyback_type: 13, mobile_beacon_type: 18, mobile_type: 14)
    backfill_cohort(beacon_type: 19, piggyback_type: 15, mobile_beacon_type: 20, mobile_type: 16)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def backfill_cohort(beacon_type:, piggyback_type:, mobile_beacon_type:, mobile_type:)
    DB.exec(<<~SQL, beacon_type:, piggyback_type:, mobile_beacon_type:, mobile_type:)
        INSERT INTO application_requests (date, req_type, count)
        SELECT piggybacks.date, transports.beacon_type, piggybacks.count
        FROM (
          VALUES (:piggyback_type, :beacon_type), (:mobile_type, :mobile_beacon_type)
        ) AS transports (piggyback_type, beacon_type)
        JOIN application_requests piggybacks ON piggybacks.req_type = transports.piggyback_type
        WHERE piggybacks.count > 0
          AND piggybacks.date < CURRENT_DATE - 1
          AND NOT EXISTS (
            SELECT 1
            FROM application_requests beacons
            WHERE beacons.date = piggybacks.date
              AND beacons.req_type = :beacon_type
              AND beacons.count > 0
          )
        ON CONFLICT (date, req_type) DO UPDATE SET count = excluded.count
      SQL
  end
end
