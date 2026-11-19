# frozen_string_literal: true

class TopicFooterPinnedPostSerializer < BasicPostSerializer
  attributes :post_number, :relative_url

  def self.for_topic(topic, guardian)
    post = topic.pinned_footer_post
    return unless post && guardian.can_see_post?(post)
    return if guardian.user&.ignored_user_ids&.include?(post.user_id)

    new(post, scope: guardian, root: false).as_json
  end

  def cooked
    fragment = Nokogiri::HTML5.fragment(super)
    fragment.css("[id]").each { |element| element.remove_attribute("id") }
    fragment.to_html
  end
end
