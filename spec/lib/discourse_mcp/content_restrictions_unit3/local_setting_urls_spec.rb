# frozen_string_literal: true

require_relative "server_support"

describe DiscourseMcp::Server do
  include McpContentRestrictionsUnit3::ServerSupport

  def setting_url_response(url)
    SiteSetting.tos_url = url
    rpc("discourse_list_site_settings", "names" => ["tos_url"]).tap do |response|
      expect_usable(response)
    end
  end

  def expect_setting_url(response, url)
    payloads(response).each do |payload|
      expect(payload.fetch("site_settings")).to include(
        a_hash_including("setting" => "tos_url", "value" => url),
      )
    end
  end

  def local_paths(family, topic:, post:, category:, tag:)
    case family
    when "topic and post"
      [
        "/p/#{post.id}",
        "/t/#{topic.slug}/#{topic.id}/#{post.post_number}",
        "/t/#{topic.id}/#{post.post_number}",
        "/t/#{topic.id}",
      ]
    when "category"
      ["/c/#{category.slug}/#{category.id}", "/c/#{category.id}"]
    when "tag"
      ["/tag/#{tag.name}", "/tags/#{tag.name}"]
    end
  end

  shared_examples "local setting URLs" do |family, rule_kind|
    it "[cr-u3] ListSiteSettings conceals absolute and relative #{family} routes under #{rule_kind}" do
      denied_category = Fabricate(:category, id: 91_310_001)
      allowed_category = Fabricate(:category, id: 91_310_002)
      denied_tag = Fabricate(:tag, name: "cru3-route-denied")
      allowed_tag = Fabricate(:tag, name: "cru3-route-allowed")
      restricted_topic =
        if rule_kind == "private_messages"
          Fabricate(:private_message_topic, id: 92_310_002, user: admin)
        else
          Fabricate(:topic, id: 92_310_002, user: admin, category: denied_category)
        end
      Fabricate(:post, topic: restricted_topic, user: admin)
      restricted_post = Fabricate(:post, id: 93_310_002, topic: restricted_topic, user: admin)
      restricted_topic.tags << denied_tag
      allowed_topic = Fabricate(:topic, user: admin, category: allowed_category)
      Fabricate(:post, topic: allowed_topic, user: admin)
      allowed_post = Fabricate(:post, topic: allowed_topic, user: admin)
      allowed_topic.tags << allowed_tag
      restricted_paths =
        local_paths(
          family,
          topic: restricted_topic,
          post: restricted_post,
          category: denied_category,
          tag: denied_tag,
        )
      allowed_paths =
        local_paths(
          family,
          topic: allowed_topic,
          post: allowed_post,
          category: allowed_category,
          tag: allowed_tag,
        )
      urls =
        restricted_paths
          .zip(allowed_paths)
          .flat_map do |restricted_path, allowed_path|
            [
              [restricted_path, allowed_path],
              ["#{Discourse.base_url}#{restricted_path}", "#{Discourse.base_url}#{allowed_path}"],
            ]
          end
      urls.flatten.each { |url| expect_setting_url(setting_url_response(url), url) }
      if rule_kind == "private_messages"
        McpContentRule.create!(rule_kind:, config: {})
      else
        forum_rule(denied_categories: [denied_category.id], denied_tags: [denied_tag.id])
      end
      expect(McpContentRule.pluck(:rule_kind)).to eq([rule_kind])
      forbidden =
        case family
        when "topic and post"
          [restricted_topic.id, restricted_post.id, restricted_topic.slug]
        when "category"
          [denied_category.id, denied_category.slug]
        when "tag"
          [denied_tag.name]
        end

      aggregate_failures do
        urls.each do |restricted_url, allowed_url|
          response = setting_url_response(restricted_url)
          expect_absent(response, [restricted_url, *forbidden], "#{rule_kind} #{restricted_url}")
          expect_setting_url(setting_url_response(allowed_url), allowed_url)
        end
      end
    end
  end

  include_examples "local setting URLs", "topic and post", "forum_content"
  include_examples "local setting URLs", "category", "forum_content"
  include_examples "local setting URLs", "tag", "forum_content"
  include_examples "local setting URLs", "topic and post", "private_messages"
end
