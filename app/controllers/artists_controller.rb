# frozen_string_literal: true
class ArtistsController < ApplicationController
  def show
    # @mb_artist = MusicBrainz::Artist.find(params[:id])
    # raise Discourse::NotFound unless @mb_artist

    @mb_artist = Listenbrainz::Api.artist(params[:id])
    @mb_artist.merge!(id: params[:id]) if @mb_artist
    render json: @mb_artist.present? ? { artist: @mb_artist } : { error: "Artist not found" }
  end
end
