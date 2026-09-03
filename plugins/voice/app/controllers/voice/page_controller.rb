# frozen_string_literal: true

module Voice
  class PageController < ApplicationController
    # Anonymous visitors may view public room pages when access is open to
    # everyone, mirroring the rooms directory; the guardian gates the rest.
    skip_before_action :ensure_logged_in

    # Without this, HTML requests short-circuit into the app shell before the
    # action runs, so unknown slugs and forbidden rooms would never 404/403.
    skip_before_action :check_xhr, only: :show

    def show
      room = Voice::Room.find_by(slug: params[:slug])
      raise Discourse::NotFound if room.blank?

      guardian.ensure_can_see_voice_room!(room)

      render "default/empty"
    end
  end
end
