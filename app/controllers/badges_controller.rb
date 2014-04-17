class BadgesController < ApplicationController
  def index
    badges = Badge.all.to_a
    render_serialized(badges, BadgeSerializer, root: "badges")
  end

  def show
    params.require(:id)
    badge = Badge.find(params[:id])
    render_serialized(badge, BadgeSerializer, root: "badge")
  end
end
