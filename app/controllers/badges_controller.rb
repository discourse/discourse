class BadgesController < ApplicationController
  skip_before_filter :check_xhr, only: [:index, :show]

  def index
    badges = Badge.all.to_a
    serialized = MultiJson.dump(serialize_data(badges, BadgeSerializer, root: "badges"))
    respond_to do |format|
      format.html do
        store_preloaded "badges", serialized
        render "default/empty"
      end
      format.json { render json: serialized }
    end
  end

  def show
    params.require(:id)
    badge = Badge.find(params[:id])
    serialized = MultiJson.dump(serialize_data(badge, BadgeSerializer, root: "badge"))
    respond_to do |format|
      format.html do
        store_preloaded "badge", serialized
        render "default/empty"
      end
      format.json { render json: serialized }
    end
  end
end
