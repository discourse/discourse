# frozen_string_literal: true

module AdPlugin
  class HouseAdsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      render_json_dump(
        house_ads:
          serialize_data(
            HouseAd.all,
            HouseAdSerializer,
            { include_categories: true, include_groups: true },
          ),
        settings: HouseAdSetting.all,
      )
    end

    def show
      house_ad = HouseAd.find_by(id: params[:id])
      raise Discourse::NotFound if house_ad.nil?

      render_json_dump(
        house_ad:
          serialize_data(
            house_ad,
            HouseAdSerializer,
            { include_categories: true, include_groups: true },
          ),
      )
    end

    def create
      ad = HouseAd.new(house_ad_params)
      if ad.save
        sync_routes(ad, house_ad_params[:routes])
        render_json_dump(
          serialize_data(ad, HouseAdSerializer, { include_categories: true, include_groups: true }),
        )
      else
        render_json_error(ad)
      end
    end

    def update
      ad = HouseAd.find_by(id: params[:id])
      raise Discourse::NotFound if ad.nil?

      if ad.update(house_ad_params.except(:routes))
        sync_routes(ad, house_ad_params[:routes])
        render_json_dump(
          serialize_data(ad, HouseAdSerializer, { include_categories: true, include_groups: true }),
        )
      else
        render_json_error(ad)
      end
    end

    def destroy
      ad = HouseAd.find_by(id: params[:id])
      raise Discourse::NotFound if ad.nil?

      ad.destroy
      render json: success_json
    end

    private

    def house_ad_params
      @permitted ||=
        begin
          permitted =
            params.permit(
              :name,
              :html,
              :visible_to_anons,
              :visible_to_logged_in_users,
              group_ids: [],
              category_ids: [],
              routes: [],
            )
          permitted[:visible_to_logged_in_users] = ActiveModel::Type::Boolean.new.cast(
            permitted[:visible_to_logged_in_users],
          )
          permitted[:visible_to_anons] = ActiveModel::Type::Boolean.new.cast(
            permitted[:visible_to_anons],
          )

          permitted[:group_ids] ||= [] if !params.key?(:group_ids)
          permitted[:category_ids] ||= [] if !params.key?(:category_ids)
          permitted[:routes] ||= [] if !params.key?(:routes)
          permitted
        end
    end

    def sync_routes(ad, route_names)
      return if route_names.nil?

      ad.routes.delete_all

      route_names.each { |route_name| ad.routes.create!(route_name: route_name) }
    end
  end
end
