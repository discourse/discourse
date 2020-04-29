# frozen_string_literal: true

# name: discourse-unsupported-browser
# about: Attempts to provide support for old and unsupported browser through polyfills
# version: 1.0
# authors: Joffrey Jaffeux, David Taylor, Daniel Waterworth, Robin Ward
# url: https://github.com/discourse/discourse/tree/master/plugins/discourse-unsupported-browser

enabled_site_setting :discourse_unsupported_browser_enabled
hide_plugin if self.respond_to?(:hide_plugin)

register_asset 'stylesheets/ie.scss'

# We can't use register asset for an optional resource. Instead copy it after plugins have
# been activated so it can be uploaded to CDNs.
DiscourseEvent.on(:after_plugin_activation) do ||
  polyfill_path = "#{Plugin::Instance.js_path}/#{self.directory_name}-optional.js"
  FileUtils.cp("#{Rails.root}/public/plugins/discourse-unsupported-browser/js/ie.js", polyfill_path)
  Rails.configuration.assets.precompile << "plugins/discourse-unsupported-browser-optional.js"
end

after_initialize do
  # Conditionally load the stylesheet
  register_asset_filter do |type, request|
    request.nil? || request.env['HTTP_USER_AGENT'] =~ /MSIE|Trident/
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
      path = controller.helpers.script_asset_path('plugins/discourse-unsupported-browser-optional')

      <<~JAVASCRIPT
        <script src="#{path}"></script>
      JAVASCRIPT
    end
  end
end
