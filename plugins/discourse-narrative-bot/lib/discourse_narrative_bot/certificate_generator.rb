# frozen_string_literal: true

module DiscourseNarrativeBot
  class CertificateGenerator
    def initialize(user, date, avatar_data)
      @user = user
      @avatar_data = avatar_data

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
      svg_default_width = 538.583
      logo_container = logo_group(55, svg_default_width, 350)

      ApplicationController.render(inline: read_template('new_user'), assigns: assign_options(svg_default_width, logo_container))
    end

    def advanced_user_track
      svg_default_width = 722.8
      logo_container = logo_group(40, svg_default_width, 280)

      ApplicationController.render(inline: read_template('advanced_user'), assigns: assign_options(svg_default_width, logo_container))
    end

    private

    def read_template(filename)
      File.read(File.expand_path("../templates/#{filename}.svg.erb", __FILE__))
    end

    def assign_options(width, logo_group)
      {
        width: width,
        discobot_user: @discobot_user,
        date: @date,
        avatar_url: base64_image_data(@avatar_data),
        logo_group: logo_group,
        name: name
      }
    end

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

    def base64_image_data(data)
      "xlink:href=\"data:image/png;base64,#{Base64.strict_encode64(data)}\""
    end

    def base64_image_link(url)
      if image = fetch_image(url)
        base64_image_data(image)
      else
        ""
      end
    end

    def fetch_image(url)
      URI(url).open('rb', redirect: true, allow_redirections: :all).read
    rescue OpenURI::HTTPError
      # Ignore if fetching image returns a non 200 response
    end
  end
end
