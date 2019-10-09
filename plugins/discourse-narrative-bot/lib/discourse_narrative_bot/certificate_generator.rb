# frozen_string_literal: true

module DiscourseNarrativeBot
  class CertificateGenerator
    def initialize(user, date)
      @user = user

      date =
        begin
          Date.parse(date)
        rescue ArgumentError => e
          if e.message == 'invalid date'
            Date.parse(Date.today.to_s)
          else
            raise e
          end
        end

      @date = I18n.l(date, format: :date_only)
      @discobot_user = User.find(-2)
    end

    def new_user_track
      width = 538.583 # Default width for the SVG
      ApplicationController.render(inline: File.read(File.expand_path('../templates/new_user.svg.erb', __FILE__)),
                                   assigns: { width: width,
                                              discobot_user: @discobot_user,
                                              date: @date,
                                              avatar_url: base64_image_link(avatar_url),
                                              logo_group: logo_group(55, width, 350),
                                              name: name })
    end

    def advanced_user_track
      width = 722.8 # Default width for the SVG
      ApplicationController.render(inline: File.read(File.expand_path('../templates/advanced_user.svg.erb', __FILE__)),
                                   assigns: { width: width,
                                              discobot_user: @discobot_user,
                                              date: @date,
                                              avatar_url: base64_image_link(avatar_url),
                                              logo_group: logo_group(40, width, 280),
                                              name: name })
    end

    private

    def name
      @user.username.titleize
    end

    def logo_group(size, width, height)
      return unless SiteSetting.site_logo_small_url.present?

      begin
        uri = URI(SiteSetting.site_logo_small_url)

        logo_uri =
          if uri.host.blank? || uri.scheme.blank?
            URI("#{Discourse.base_url}/#{uri.path}")
          else
            uri
          end

        <<~URL
          <g transform="translate(#{width / 2 - (size / 2)} #{height})">
            <image height="#{size}px" width="#{size}px" #{base64_image_link(logo_uri)}/>
          </g>
          URL
      rescue URI::InvalidURIError
        ''
      end
    end

    def base64_image_link(url)
      if image = fetch_image(url)
        "xlink:href=\"data:image/png;base64,#{Base64.strict_encode64(image)}\""
      else
        ""
      end
    end

    def fetch_image(url)
      URI(url).open('rb', redirect: true, allow_redirections: :all).read
    rescue OpenURI::HTTPError
      # Ignore if fetching image returns a non 200 response
    end

    def avatar_url
      UrlHelper.absolute(Discourse.base_uri + @user.avatar_template.gsub('{size}', '250'))
    end
  end
end
