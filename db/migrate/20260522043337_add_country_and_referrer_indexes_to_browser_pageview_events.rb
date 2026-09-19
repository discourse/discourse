# frozen_string_literal: true

class AddCountryAndReferrerIndexesToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  COUNTRY_INDEX = "idx_bpe_created_at_country_code"
  REFERRER_INDEX = "idx_bpe_created_at_normalized_referrer"

  def up
    remove_index :browser_pageview_events,
                 name: COUNTRY_INDEX,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :browser_pageview_events,
              %i[created_at country_code],
              name: COUNTRY_INDEX,
              algorithm: :concurrently

    remove_index :browser_pageview_events,
                 name: REFERRER_INDEX,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :browser_pageview_events,
              %i[created_at normalized_referrer],
              name: REFERRER_INDEX,
              algorithm: :concurrently
  end

  def down
    remove_index :browser_pageview_events,
                 name: COUNTRY_INDEX,
                 algorithm: :concurrently,
                 if_exists: true
    remove_index :browser_pageview_events,
                 name: REFERRER_INDEX,
                 algorithm: :concurrently,
                 if_exists: true
  end
end
