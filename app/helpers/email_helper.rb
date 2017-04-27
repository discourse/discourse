module EmailHelper

  def mailing_list_topic(topic, post_count)
    render(
      partial: partial_for("mailing_list_post"),
      locals: { topic: topic, post_count: post_count }
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
    raw "<a href='#{Discourse.base_url}#{url}' style='color: ##{@anchor_color}'>#{title}</a>"
  end

  protected

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
