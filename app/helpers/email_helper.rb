# frozen_string_literal: true

require "erb"

module EmailHelper
  def mailing_list_topic(topic, post_count)
    render(
      partial: partial_for("mailing_list_post"),
      locals: {
        topic: topic,
        post_count: post_count,
      },
    )
  end

  def mailing_list_topic_text(topic)
    url, title = extract_details(topic)
    raw(@markdown_linker.create(title, url))
  end

  def private_topic_title(topic)
    I18n.t("system_messages.private_topic_title", id: topic.id)
  end

  def email_topic_link(topic)
    url, title = extract_details(topic)
    raw "<a href='#{Discourse.base_url_no_prefix}#{url}' style='color: ##{@anchor_color}'>#{title}</a>"
  end

  def email_html_template
    EmailStyle
      .new
      .html
      .sub("%{email_content}") { capture { yield } }
      .gsub("%{html_lang}", html_lang)
      .gsub("%{dark_mode_meta_tags}", dark_mode_meta_tags)
      .gsub("%{dark_mode_styles}", dark_mode_styles)
      .html_safe
  end

  protected

  def dark_mode_meta_tags
    "
    <meta name='color-scheme' content='light dark' />
    <meta name='supported-color-schemes' content='light dark' />
    "
  end

  def dark_mode_styles
    "
    <style>
      @media (prefers-color-scheme: dark) {
        html {
          background: #151515 !important;
        }

        h1,
        h2,
        h3,
        h4,
        h5,
        h6,
        p,
        span,
        td {
          color: inherit !important;
        }

        [data-stripped-secure-media] {
          border-color: #454545 !important;
        }

        [data-stripped-secure-upload] {
          border-color: #454545 !important;
        }

        [dm='text-color'] {
          color: #dddddd;
        }

        [dm='header'] {
          background: #151515 !important;
        }

        [dm='topic-body'] {
          background: #151515 !important;
          border-bottom: 1px solid #454545 !important;
        }

        [dm='triangle'] {
          border-top-color: #151515 !important;
        }

        [dm='body'] {
          background: #222222 !important;
          color: #dddddd !important;
        }

        [dm='body_primary'] {
          background: #062e3d !important;
          color: #dddddd !important;
        }

        [dm='bg'] {
          background: #323232 !important;
          border-color: #454545 !important;
        }
      }
    </style>
    "
  end

  def extract_details(topic)
    if SiteSetting.private_email?
      [topic.slugless_url, private_topic_title(topic)]
    else
      [topic.relative_url, format_topic_title(topic.title)]
    end
  end

  def partial_for(name)
    SiteSetting.private_email? ? "email/secure_#{name}" : "email/#{name}"
  end
end
