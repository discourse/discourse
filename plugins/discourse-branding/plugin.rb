# name: branding
# about: Plugin to add a custom brand header for Discourse
# version: 0.2.2
# authors: Vinoth Kannan (vinothkannan@vinkas.com)
# url: https://github.com/vinkas0/discourse-branding

enabled_site_setting :branding_enabled

register_asset 'stylesheets/branding.scss'
register_asset "javascripts/branding.js"

after_initialize do
  ApplicationController.class_eval do
    alias_method :discourse_set_layout, :set_layout

    def set_layout
      if SiteSetting.branding_enabled
        if use_crawler_layout?
          'crawler'
        else
          File.expand_path('../app/views/layouts/application.html.erb', __FILE__)
        end
      else
        discourse_set_layout
      end
    end
  end

  ApplicationHelper.module_eval do
    def site_title
      if SiteSetting.branding_enabled
        SiteSetting.brand_name + ' ' + SiteSetting.title
      else
        SiteSetting.title
      end
    end
  end

end
