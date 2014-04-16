class BadgesController < ApplicationController
  def index
    badges = Badge.all.to_a
    render_serialized(badges, BadgeSerializer, root: "badges")
  end
end
