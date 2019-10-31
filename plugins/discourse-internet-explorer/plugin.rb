# frozen_string_literal: true

# name: discourse-internet-explorer
# about: Attempts to provide backward support for internt explorer
# version: 1.0
# authors: Joffrey Jaffeux, David Taylor, Daniel Waterworth
# url: https://github.com/discourse/discourse/tree/master/plugins/discourse-internet-explorer

enabled_site_setting :discourse_internet_explorer_enabled
hide_plugin if self.respond_to?(:hide_plugin)

register_asset 'stylesheets/ie.scss'

after_initialize do
  reloadable_patch do |plugin|
    if plugin.enabled?
      # patching discourse_stylesheet_link_tag so we can still use scss
      ApplicationHelper.module_eval do
        alias_method :previous_discourse_stylesheet_link_tag, :discourse_stylesheet_link_tag
        def discourse_stylesheet_link_tag(name, opts = {})
          if name === 'discourse-internet-explorer'
            unless request.env['HTTP_USER_AGENT'] =~ /MSIE|Trident/
              return
            end
          end

          previous_discourse_stylesheet_link_tag(name, opts)
        end
      end
    end
  end

  # not using patch on preload_script as js is fine and we need this file
  # to be loaded before other files
  register_html_builder('server:before-script-load') do |controller|
    if controller.request.env['HTTP_USER_AGENT'] =~ /MSIE|Trident/
      path = controller.helpers.script_asset_path('/plugins/discourse-internet-explorer/js/ie')

      <<~JAVASCRIPT
        <script src="#{path}"></script>
      JAVASCRIPT
    end
  end
end
