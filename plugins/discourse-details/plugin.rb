# name: discourse-details
# about: HTML5.1 Details polyfill for Discourse
# version: 0.3
# authors: Régis Hanol
# url: https://github.com/discourse/discourse/tree/master/plugins/discourse-details

enabled_site_setting :details_enabled

register_asset "javascripts/details.js"
register_asset "javascripts/details_dialect.js", :server_side

register_asset "stylesheets/details.scss"

after_initialize do

  # replace all details with their summary in emails
  Email::Styles.register_plugin_style do |fragment|
    if SiteSetting.details_enabled
      fragment.css("details").each do |details|
        summary = details.css("summary")[0]
        summary.name = "p"
        details.replace(summary)
      end
    end
  end

end
