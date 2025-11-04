# frozen_string_literal: true

class MigrateHouseAdsFromPluginStore < ActiveRecord::Migration[7.0]
  def up
    # Get all house ads from PluginStore
    plugin_store_ads =
      PluginStoreRow
        .where(plugin_name: "discourse-adplugin")
        .where("key LIKE 'ad:%'")
        .where("key != 'ad:_id'")

    return if plugin_store_ads.empty?

    existing_ids = DB.query_single("SELECT id FROM ad_plugin_house_ads").to_set

    ads_data = []
    groups_data = []
    categories_data = []

    plugin_store_ads.each do |psr|
      data = PluginStore.cast_value(psr.type_name, psr.value)

      next if existing_ids.include?(data[:id])

      ads_data << {
        id: data[:id],
        name: data[:name],
        html: data[:html],
        visible_to_logged_in_users: data[:visible_to_logged_in_users],
        visible_to_anons: data[:visible_to_anons],
      }

      if data[:group_ids].present?
        data[:group_ids].each { |group_id| groups_data << { ad_id: data[:id], group_id: group_id } }
      end

      if data[:category_ids].present?
        data[:category_ids].each do |category_id|
          categories_data << { ad_id: data[:id], category_id: category_id }
        end
      end
    end

    return if ads_data.empty?

    ads_values =
      ads_data
        .map do |ad|
          "(#{ad[:id]}, #{DB.quote(ad[:name])}, #{DB.quote(ad[:html])}, #{ad[:visible_to_logged_in_users]}, #{ad[:visible_to_anons]}, NOW(), NOW())"
        end
        .join(",")

    DB.exec(<<~SQL)
      INSERT INTO ad_plugin_house_ads (id, name, html, visible_to_logged_in_users, visible_to_anons, created_at, updated_at)
      VALUES #{ads_values}
      ON CONFLICT (id) DO NOTHING
    SQL

    if groups_data.any?
      groups_values = groups_data.map { |g| "(#{g[:ad_id]}, #{g[:group_id]})" }.join(",")

      DB.exec(<<~SQL)
        INSERT INTO ad_plugin_house_ads_groups (ad_plugin_house_ad_id, group_id)
        VALUES #{groups_values}
        ON CONFLICT DO NOTHING
      SQL
    end

    if categories_data.any?
      categories_values = categories_data.map { |c| "(#{c[:ad_id]}, #{c[:category_id]})" }.join(",")

      DB.exec(<<~SQL)
        INSERT INTO ad_plugin_house_ads_categories (ad_plugin_house_ad_id, category_id)
        VALUES #{categories_values}
        ON CONFLICT DO NOTHING
      SQL
    end

    max_id = DB.query_single("SELECT MAX(id) FROM ad_plugin_house_ads").first || 0
    DB.exec("SELECT setval('ad_plugin_house_ads_id_seq', ?)", max_id + 1) if max_id > 0
  end

  def down
    ads = DB.query(<<~SQL)
      SELECT
        ha.id,
        ha.name,
        ha.html,
        ha.visible_to_logged_in_users,
        ha.visible_to_anons,
        ARRAY_AGG(DISTINCT hag.group_id) FILTER (WHERE hag.group_id IS NOT NULL) as group_ids,
        ARRAY_AGG(DISTINCT hac.category_id) FILTER (WHERE hac.category_id IS NOT NULL) as category_ids
      FROM ad_plugin_house_ads ha
      LEFT JOIN ad_plugin_house_ads_groups hag ON ha.id = hag.ad_plugin_house_ad_id
      LEFT JOIN ad_plugin_house_ads_categories hac ON ha.id = hac.ad_plugin_house_ad_id
      GROUP BY ha.id, ha.name, ha.html, ha.visible_to_logged_in_users, ha.visible_to_anons
    SQL

    ads.each do |ad|
      PluginStore.set(
        "discourse-adplugin",
        "ad:#{ad.id}",
        {
          id: ad.id,
          name: ad.name,
          html: ad.html,
          visible_to_logged_in_users: ad.visible_to_logged_in_users,
          visible_to_anons: ad.visible_to_anons,
          group_ids: ad.group_ids || [],
          category_ids: ad.category_ids || [],
        },
      )
    end

    max_id = ads.map(&:id).max || 0
    PluginStore.set("discourse-adplugin", "ad:_id", max_id + 1) if max_id > 0

    puts "Migrated #{ads.count} house ads back to PluginStore"
  end
end
