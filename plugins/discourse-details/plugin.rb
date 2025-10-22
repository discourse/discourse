# frozen_string_literal: true

# name: discourse-details
# about: HTML5.1 Details polyfill for Discourse
# version: 0.4
# authors: Régis Hanol
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-details

enabled_site_setting :details_enabled

register_asset "stylesheets/details.scss"

after_initialize do
  Email::Styles.register_plugin_style do |fragment|
    # remove all elided content
    fragment.css("details.elided").each(&:remove)

    # replace all details with their summary in emails
    fragment
      .css("details")
      .each do |details|
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

  on(:reduce_cooked) do |fragment, post|
    fragment
      .css("details")
      .each do |el|
        text = el.css("summary").text
        link = fragment.document.create_element("a")
        link["href"] = post&.url.presence || Discourse.base_url
        link.content = I18n.t("details.excerpt_details")
        el.replace CGI.escapeHTML(text) + " " + link.to_html
      end
  end
end
