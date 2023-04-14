# frozen_string_literal: true

class SlugsController < ApplicationController
  requires_login

  MAX_SLUG_GENERATIONS_PER_MINUTE = 20

  def generate
    params.require(:name)

    raise Discourse::InvalidAccess if !current_user.has_trust_level_or_staff?(TrustLevel[4])

    RateLimiter.new(
      current_user,
      "max-slug-generations-per-minute",
      MAX_SLUG_GENERATIONS_PER_MINUTE,
      1.minute,
    ).performed!

    render json: success_json.merge(slug: Slug.for(params[:name], ""))
  end
end
