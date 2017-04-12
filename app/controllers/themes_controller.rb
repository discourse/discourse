class ThemesController < ::ApplicationController
  def assets
    theme_key = params[:key].to_s

    if theme_key == "default"
      theme_key = nil
    else
      raise Discourse::NotFound unless Theme.where(key: theme_key).exists?
    end

    object = [:mobile, :desktop, :desktop_theme, :mobile_theme].map do |target|
      link = Stylesheet::Manager.stylesheet_link_tag(target, 'all', params[:key])
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
