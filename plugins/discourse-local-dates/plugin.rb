# name: discourse-local-dates
# about: Display a date in your local timezone
# version: 0.1
# author: Joffrey Jaffeux
hide_plugin if self.respond_to?(:hide_plugin)

register_asset "javascripts/discourse-local-dates.js"
register_asset "stylesheets/common/discourse-local-dates.scss"
register_asset "moment.js", :vendored_core_pretty_text
register_asset "moment-timezone.js", :vendored_core_pretty_text

enabled_site_setting :discourse_local_dates_enabled

after_initialize do
  on(:reduce_cooked) do |fragment|
    container = fragment.css(".discourse-local-date").first

    if container && container.attributes["data-email-preview"]
      preview = container.attributes["data-email-preview"].value
      container.content = preview
    end
  end
end

load File.expand_path('../lib/discourse_local_dates/engine.rb', __FILE__)
