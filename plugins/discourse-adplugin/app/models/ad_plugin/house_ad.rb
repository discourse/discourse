# frozen_string_literal: true

module AdPlugin
  class HouseAd < ActiveRecord::Base
    self.table_name = "ad_plugin_house_ads"

    NAME_REGEX = /\A[[:alnum:]\s\.,'!@#$%&\*\-\+\=:]*\z/i

    has_many :impressions,
             class_name: "AdPlugin::AdImpression",
             foreign_key: "ad_plugin_house_ad_id",
             dependent: :destroy

    has_many :routes,
             class_name: "AdPlugin::HouseAdRoute",
             foreign_key: "ad_plugin_house_ad_id",
             dependent: :delete_all

    has_and_belongs_to_many :groups,
                            join_table: "ad_plugin_house_ads_groups",
                            foreign_key: "ad_plugin_house_ad_id",
                            association_foreign_key: "group_id"

    has_and_belongs_to_many :categories,
                            join_table: "ad_plugin_house_ads_categories",
                            foreign_key: "ad_plugin_house_ad_id",
                            association_foreign_key: "category_id"

    validates :name, presence: true, uniqueness: true, format: { with: NAME_REGEX }
    validates :html, presence: true

    scope :for_anons, -> { where(visible_to_anons: true) }
    scope :for_logged_in, -> { where(visible_to_logged_in_users: true) }

    after_destroy :clear_cache
    after_save :clear_cache

    def self.all_for_anons
      for_anons.to_a
    end

    def self.all_for_logged_in_users(scope)
      query = for_logged_in
      return query if scope.nil?

      query =
        query
          .left_joins(:groups)
          .where(
            "ad_plugin_house_ads_groups.group_id IN (?) OR ad_plugin_house_ads_groups.group_id = ? OR ad_plugin_house_ads_groups.group_id IS NULL",
            scope.user.group_ids,
            Group::AUTO_GROUPS[:everyone],
          )
          .distinct

      category_ids = Category.secured(scope).pluck(:id)
      query =
        query
          .left_joins(:categories)
          .where(
            "ad_plugin_house_ads_categories.category_id IN (?) OR ad_plugin_house_ads_categories.category_id IS NULL",
            category_ids,
          )
          .distinct

      query.to_a
    end

    def route_names
      routes.pluck(:route_name)
    end

    private

    def clear_cache
      Site.clear_anon_cache!
      self.class.publish_if_ads_enabled
    end

    def self.publish_if_ads_enabled
      if AdPlugin::HouseAdSetting.all.any? { |_, ads_to_show| ads_to_show.present? }
        AdPlugin::HouseAdSetting.publish_settings
      end
    end
  end
end

# == Schema Information
#
# Table name: ad_plugin_house_ads
#
#  id                         :bigint           not null, primary key
#  html                       :text             not null
#  name                       :string           not null
#  visible_to_anons           :boolean          default(TRUE), not null
#  visible_to_logged_in_users :boolean          default(TRUE), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#
# Indexes
#
#  index_ad_plugin_house_ads_on_name                        (name) UNIQUE
#  index_ad_plugin_house_ads_on_visible_to_anons            (visible_to_anons)
#  index_ad_plugin_house_ads_on_visible_to_logged_in_users  (visible_to_logged_in_users)
#
