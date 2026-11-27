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
    targets = {}
    fragment
      .css("[id]")
      .each do |element|
        id = element["id"]
        element["id"] = targets[id] = "footer-post-#{object.id}-#{id}"
      end
    fragment
      .css('a[href^="#"]')
      .each do |anchor|
        if target = targets[anchor["href"].delete_prefix("#")]
          anchor["href"] = "##{target}"
        end
      end
    fragment.to_html
  end
end
