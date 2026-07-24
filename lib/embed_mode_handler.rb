# frozen_string_literal: true

# Shared embed-mode handling for controllers that render the full app inside an
# embedding iframe (see EmbedController). Including controllers are expected to
# register the filters with the appropriate actions, e.g.:
#
#   before_action :set_embed_class, only: :show
#   after_action :allow_embed_mode, only: :show
module EmbedModeHandler
  # Drops X-Frame-Options so the page can be framed by an allowed embedding host.
  def allow_embed_mode
    response.headers.delete("X-Frame-Options") if embed_mode_allowed?
  end

  # Applies the `class_name` passed by the embedding page to the `<html>`
  # element of the full app (via `html_classes`), mirroring classic embed mode.
  def set_embed_class
    return unless embed_mode_allowed?
    return if params[:class_name].blank?
    return unless params[:class_name].match?(/\A[a-zA-Z0-9\-_ ]+\z/)

    @embed_class = params[:class_name]
  end

  def embed_mode_allowed?
    return @embed_mode_allowed if defined?(@embed_mode_allowed)

    @embed_mode_allowed =
      if params[:embed_mode].blank? || !SiteSetting.embed_full_app
        false
      else
        SiteSetting.embed_any_origin? || EmbeddableHost.record_for_url(request.referer).present?
      end
  end
end
