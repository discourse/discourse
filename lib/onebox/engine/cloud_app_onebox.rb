# frozen_string_literal: true

module Onebox
  module Engine
    class CloudAppOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/cl\.ly/)
      always_https

      def to_html
        og = get_opengraph

        if !og.image.nil?
          image_html(og)
        elsif og.title.to_s[/\.(mp4|ogv|webm)$/]
          video_html(og)
        else
          link_html(og)
        end
      end

      private

      def link_html(og)
        <<-HTML
          <a href='#{og.url}' target='_blank' rel='noopener'>
            #{og.title}
          </a>
        HTML
      end

      def video_html(og)
        direct_src = ::Onebox::Helpers.normalize_url_for_output("#{og.get(:url)}/#{og.title}")

        <<-HTML
          <video width='480' height='360' #{og.title_attr} controls loop>
            <source src='#{direct_src}' type='video/mp4'>
          </video>
        HTML
      end

      def image_html(og)
        <<-HTML
          <a href='#{og.url}' target='_blank' class='onebox' rel='noopener'>
            <img src='#{og.image}' #{og.title_attr} alt='CloudApp' width='480'>
          </a>
        HTML
      end
    end
  end
end
