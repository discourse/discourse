class ThemesController < ::ApplicationController
  def assets
    theme_id = params[:id].to_i

    if params[:id] == "default"
      theme_id = nil
    else
      raise Discourse::NotFound unless Theme.where(id: theme_id).exists?
    end

    object = [:mobile, :desktop, :desktop_theme, :mobile_theme].map do |target|
      link = Stylesheet::Manager.stylesheet_link_tag(target, 'all', params[:id])
      if link
        href = link.split(/["']/)[1]
        if Rails.env.development?
          href << (href.include?("?") ? "&" : "?")
          href << SecureRandom.hex
        end
        {
          target: target,
          url: href
        }
      end
    end.compact

    render json: object.as_json
  end
end
