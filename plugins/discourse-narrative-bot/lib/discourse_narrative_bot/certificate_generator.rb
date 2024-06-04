# frozen_string_literal: true

module DiscourseNarrativeBot
  class CertificateGenerator
    def initialize(user, date, avatar_url)
      @user = user
      @avatar_url = avatar_url

      date =
        begin
          Date.parse(date)
        rescue ArgumentError => e
          if e.message == "invalid date"
            Date.parse(Date.today.to_s)
          else
            raise e
          end
        end

      @date = I18n.l(date, format: :date_only)
      @discobot_user = ::DiscourseNarrativeBot::Base.new.discobot_user
    end

    def new_user_track
      svg_default_width = 538.583
      logo_container = logo_group(55, svg_default_width, 280)

      ApplicationController.render(
        inline: read_template("new_user"),
        assigns: assign_options(svg_default_width, logo_container),
      )
    end

    def advanced_user_track
      svg_default_width = 722.8
      logo_container = logo_group(40, svg_default_width, 350)

      ApplicationController.render(
        inline: read_template("advanced_user"),
        assigns: assign_options(svg_default_width, logo_container),
      )
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
        avatar_url: @avatar_url,
        logo_group: logo_group,
        name: name,
      }
    end

    def name
      @user.username.titleize
    end

    def logo_group(size, width, height)
      return if SiteSetting.site_logo_small_url.blank?

      uri = URI(SiteSetting.site_logo_small_url)

      logo_uri =
        if uri.host.blank? || uri.scheme.blank?
          URI("#{Discourse.base_url}/#{uri.path}")
        else
          uri
        end

      { size: size, width: width, height: height, logo_uri: logo_uri }
    end
  end
end
