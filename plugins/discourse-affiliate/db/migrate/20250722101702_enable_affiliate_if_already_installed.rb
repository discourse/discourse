# frozen_string_literal: true

class EnableAffiliateIfAlreadyInstalled < ActiveRecord::Migration[7.2]
  CONFIG_SETTINGS = %w[
    affiliate_amazon_ca
    affiliate_amazon_cn
    affiliate_amazon_co_jp
    affiliate_amazon_co_uk
    affiliate_amazon_com
    affiliate_amazon_com_au
    affiliate_amazon_com_br
    affiliate_amazon_com_mx
    affiliate_amazon_de
    affiliate_amazon_es
    affiliate_amazon_fr
    affiliate_amazon_in
    affiliate_amazon_it
    affiliate_amazon_nl
    affiliate_amazon_eu
    affiliate_ldlc_com
  ].freeze

  def up
    is_configured = DB.query_single(<<~SQL, CONFIG_SETTINGS)&.first
      SELECT 1 FROM site_settings
      WHERE name IN (?)
      AND value != ''
      LIMIT 1
    SQL

    if is_configured
      # The plugin was installed before we changed it to be disabled-by-default
      # Therefore, if there is no existing database value, enable the plugin
      execute <<~SQL
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('affiliate_enabled', 5, 't', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
