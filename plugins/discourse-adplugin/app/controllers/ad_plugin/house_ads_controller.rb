# frozen_string_literal: true

module AdPlugin
  class HouseAdsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      render_json_dump(
        house_ads:
          HouseAd.all.map do |ad|
            ad.to_hash.merge!(categories: Category.secured(@guardian).where(id: ad.category_ids))
          end,
        settings: HouseAdSetting.all,
      )
    end

    def show
      house_ad_hash = HouseAd.find(params[:id])&.to_hash
      if house_ad_hash
        house_ad_hash.merge!(
          categories: Category.secured(@guardian).where(id: house_ad_hash[:category_ids]),
        )
      end
      render_json_dump(house_ad: house_ad_hash)
    end

    def create
      ad = HouseAd.create(house_ad_params)
      ad.valid? ? render_json_dump(house_ad: ad.to_hash) : render_json_error(ad)
    end

    def update
      if ad = HouseAd.find(house_ad_params[:id])
        ad.update(house_ad_params)
      else
        ad = HouseAd.create(house_ad_params.except(:id))
      end

      ad.valid? ? render_json_dump(house_ad: ad.to_hash) : render_json_error(ad)
    end

    def destroy
      if ad = HouseAd.find(house_ad_params[:id])
        ad.destroy
      else
        render_json_error(I18n.t("not_found"), status: 404)
      end
    end

    private

    def house_ad_params
      @permitted ||=
        begin
          permitted =
            params.permit(
              :id,
              :name,
              :html,
              :visible_to_anons,
              :visible_to_logged_in_users,
              group_ids: [],
              category_ids: [],
            )
          permitted[:visible_to_logged_in_users] = ActiveModel::Type::Boolean.new.cast(
            permitted[:visible_to_logged_in_users],
          )
          permitted[:visible_to_anons] = ActiveModel::Type::Boolean.new.cast(
            permitted[:visible_to_anons],
          )
          permitted
        end
    end
  end
end
