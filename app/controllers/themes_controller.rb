class ThemesController < ::ApplicationController
  def assets
    theme_ids = params[:ids].to_s.split("-").map(&:to_i)

    if params[:ids] == "default"
      theme_ids = nil
    else
      raise Discourse::NotFound unless guardian.allow_themes?(theme_ids)
    end

    targets = view_context.mobile_view? ? [:mobile, :mobile_theme] : [:desktop, :desktop_theme]
    targets << :admin if guardian.is_staff?

    object = targets.map do |target|
      Stylesheet::Manager.stylesheet_data(target, theme_ids).map do |hash|
        next hash unless Rails.env.development?

        dup_hash = hash.dup
        dup_hash[:new_href] << (dup_hash[:new_href].include?("?") ? "&" : "?")
        dup_hash[:new_href] << SecureRandom.hex
        dup_hash
      end
    end.flatten

    render json: object.as_json
  end
end
