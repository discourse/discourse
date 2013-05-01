require 'open-uri'
require_dependency 'oneboxer/base_onebox'

module Oneboxer

  class HandlebarsOnebox < BaseOnebox

    MAX_TEXT = 500

    def self.template_path(template_name)
      "#{Rails.root}/lib/oneboxer/templates/#{template_name}.hbrs"
    end

    def template_path(template_name)
      HandlebarsOnebox.template_path(template_name)
    end

    def template
      template_name = self.class.name.underscore
      template_name.gsub!(/oneboxer\//, '')
      template_path(template_name)
    end

    def default_url
      "<a href='#{@url}' target='_blank'>#{@url}</a>"
    end

    def http_params
      {'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 5_0_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9A405 Safari/7534.48.3'}
    end

    def onebox
      html = open(translate_url, http_params).read
      args = parse(html)
      return default_url unless args.present?
      args[:original_url] = @url
      args[:lang] = @lang || ""
      args[:favicon] = ActionController::Base.helpers.image_path(self.class.favicon_file) if self.class.favicon_file.present?
      args[:host] = nice_host

      HandlebarsOnebox.generate_onebox(template,args)
    rescue => ex
      # If there's an exception, just embed the link
      raise ex if Rails.env.development?
      default_url
    end

    def self.generate_onebox(template, args)
      Mustache.render(File.read(template), args)
    end

  end

end
