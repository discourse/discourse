# frozen_string_literal: true

# name: discourse-internet-explorer
# about: Attempts to provide backward support for internt explorer
# version: 1.0
# authors: Joffrey Jaffeux, David Taylor, Daniel Waterworth, Robin Ward
# url: https://github.com/discourse/discourse/tree/master/plugins/discourse-internet-explorer

enabled_site_setting :discourse_internet_explorer_enabled
hide_plugin if self.respond_to?(:hide_plugin)

register_asset 'stylesheets/ie.scss'

# We can't use register asset for an optional resource. Instead copy it after plugins have
# been activated so it can be uploaded to CDNs.
DiscourseEvent.on(:after_plugin_activation) do ||
  polyfill_path = "#{Plugin::Instance.js_path}/#{self.directory_name}-optional.js"
  FileUtils.cp("#{Rails.root}/public/plugins/discourse-internet-explorer/js/ie.js", polyfill_path)
  Rails.configuration.assets.precompile << "plugins/discourse-internet-explorer-optional.js"
end

after_initialize do

  # Conditionally load the stylesheet. There is unfortunately no easy way to do this via
  # Plugin API.
  reloadable_patch do |plugin|
    ApplicationHelper.module_eval do
      alias_method :previous_discourse_stylesheet_link_tag, :discourse_stylesheet_link_tag
      def discourse_stylesheet_link_tag(name, opts = {})

        if name == 'discourse-internet-explorer'
          return unless SiteSetting.discourse_internet_explorer_enabled?
          return unless request.env['HTTP_USER_AGENT'] =~ /MSIE|Trident/
        end

        previous_discourse_stylesheet_link_tag(name, opts)
      end
    end
  end

  register_anonymous_cache_key(:ie) do
    unless defined?(@is_ie)
      session = @env[self.class::RACK_SESSION]
      # don't initialize params until later
      # otherwise you get a broken params on the request
      params = {}

      @is_ie = BrowserDetection.browser(@env[self.class::USER_AGENT]) == :ie
    end

    @is_ie
  end

  # not using patch on preload_script as js is fine and we need this file
  # to be loaded before other files
  register_html_builder('server:before-script-load') do |controller|
    if BrowserDetection.browser(controller.request.env['HTTP_USER_AGENT']) == :ie
      path = controller.helpers.script_asset_path('plugins/discourse-internet-explorer-optional')

      <<~JAVASCRIPT
        <script src="#{path}"></script>
      JAVASCRIPT
    end
  end
end
