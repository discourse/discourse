# name: discourse-details
# about: HTML5.1 Details polyfill for Discourse
# version: 0.4
# authors: Régis Hanol
# url: https://github.com/discourse/discourse/tree/master/plugins/discourse-details

enabled_site_setting :details_enabled

register_asset "javascripts/details.js"
register_asset "javascripts/details_dialect.js", :server_side

register_asset "stylesheets/details.scss"

after_initialize do

  Email::Styles.register_plugin_style do |fragment|
    # remove all elided content
    fragment.css("details.elided").each { |d| d.remove }

    # replace all details with their summary in emails
    fragment.css("details").each do |details|
      summary = details.css("summary")
      if summary && summary[0]
        summary = summary[0]
        if summary && summary.respond_to?(:name)
          summary.name = "p"
          details.replace(summary)
        end
      end
    end
  end

end
