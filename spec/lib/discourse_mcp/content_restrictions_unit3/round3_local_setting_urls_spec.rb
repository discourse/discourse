# frozen_string_literal: true

require_relative "server_support"

describe DiscourseMcp::Server do
  include McpContentRestrictionsUnit3::ServerSupport

  let(:denied_category) { Fabricate(:category, id: 94_510_001) }
  let(:allowed_category) { Fabricate(:category, id: 94_510_002) }
  let(:denied_tag) { Fabricate(:tag, id: 97_510_001, name: "cru3-r3-denied") }
  let(:allowed_tag) { Fabricate(:tag, id: 97_510_002, name: "cru3-r3-allowed") }
  let(:allowed_topic) { Fabricate(:topic, id: 95_510_002, user: admin, category: allowed_category) }
  let(:allowed_post) { Fabricate(:post, id: 96_510_002, topic: allowed_topic, user: admin) }

  def setting_url_response(url)
    SiteSetting.tos_url = url
    rpc("discourse_list_site_settings", "names" => ["tos_url"]).tap do |result|
      expect_usable(result)
    end
  end

  def expect_kept_url(url)
    payloads(setting_url_response(url)).each do |payload|
      expect(payload.fetch("site_settings")).to include(
        a_hash_including("setting" => "tos_url", "value" => url),
      )
    end
  end

  def expect_concealed_paths(path_pairs)
    url_pairs =
      path_pairs.flat_map do |restricted_path, allowed_path|
        [
          [restricted_path, allowed_path],
          ["#{Discourse.base_url}#{restricted_path}", "#{Discourse.base_url}#{allowed_path}"],
        ]
      end
    url_pairs.flatten.each { |url| expect_kept_url(url) }
    yield

    aggregate_failures do
      url_pairs.each do |restricted_url, allowed_url|
        expect_kept_url(allowed_url)
        result = setting_url_response(restricted_url)
        payloads(result).each do |payload|
          expect(payload.fetch("site_settings")).to include(
            a_hash_including(
              "setting" => "tos_url",
              "value" => nil,
              "default" => nil,
              "redacted" => true,
            ),
          ),
          "restricted URL retained: #{restricted_url} in #{payload.inspect}"
        end
        expect_absent(result, [restricted_url], restricted_url)
      end
    end
  end

  def restrict_urls(rule_kind)
    if rule_kind == "private_messages"
      McpContentRule.create!(rule_kind:, config: {})
    else
      forum_rule(denied_categories: [denied_category.id], denied_tags: [denied_tag.id])
    end
    expect(McpContentRule.pluck(:rule_kind)).to eq([rule_kind])
  end

  def restricted_topic(rule_kind)
    if rule_kind == "private_messages"
      Fabricate(:private_message_topic, id: 95_510_001, user: admin)
    else
      Fabricate(:topic, id: 95_510_001, user: admin, category: denied_category)
    end
  end

  def redirect_destination(path, status:)
    client = ActionDispatch::Integration::Session.new(Rails.application)
    client.host! Discourse.current_hostname
    client.get(path)
    expect(client.response.status).to eq(status), client.response.body
    URI(client.response.headers.fetch("Location")).path
  end

  shared_examples "topic_id setting URLs" do |shape, rule_kind|
    it "[cr-u3] ListSiteSettings conceals absolute and relative #{shape} URLs under #{rule_kind}" do
      SiteSetting.nested_replies_enabled = true if shape == "nested_topics"
      topic = restricted_topic(rule_kind)
      Fabricate(:post, topic:, user: admin)
      Fabricate(:post, topic: allowed_topic, user: admin)
      post = Fabricate(:post, id: 96_510_001, topic:, user: admin)
      paths =
        [topic, allowed_topic].map do |record|
          case shape
          when "raw"
            "/raw/#{record.id}"
          when "posts/by_number"
            "/posts/by_number/#{record.id}/#{post.post_number}"
          when "nested_topics"
            "/n/#{record.slug}/#{record.id}"
          end
        end
      allowed_post
      expect(post.id).not_to eq(topic.id)
      expect(post.post_number).to eq(2)
      expect(allowed_post.post_number).to eq(post.post_number)
      expect(Post.exists?(id: topic.id)).to eq(false)
      paths
        .zip([topic, allowed_topic])
        .each do |path, record|
          expect(Discourse.route_for(path)).to include(topic_id: record.id.to_s)
        end

      expect_concealed_paths([paths]) { restrict_urls(rule_kind) }
    end
  end

  %w[forum_content private_messages].each do |rule_kind|
    %w[raw posts/by_number nested_topics].each do |shape|
      include_examples "topic_id setting URLs", shape, rule_kind
    end
  end

  shared_examples "category action setting URLs" do |action|
    it "[cr-u3] ListSiteSettings conceals absolute and relative category #{action} URLs under forum_content" do
      paths =
        [denied_category, allowed_category].map do |category|
          key = action == "show" ? category.id : category.slug
          path = "/c/#{key}/#{action}"
          parameter = action == "show" ? :id : :category_slug
          expect(Discourse.route_for(path)).to include(
            :controller => "categories",
            parameter => key.to_s,
          )
          path
        end

      expect_concealed_paths([paths]) { restrict_urls("forum_content") }
    end
  end

  include_examples "category action setting URLs", "show"
  include_examples "category action setting URLs", "edit"
  include_examples "category action setting URLs", "find_by_slug"

  it "[cr-u3] ListSiteSettings conceals absolute and relative renamed tag id redirect URLs under forum_content" do
    retired_slug = denied_tag.slug_for_url
    denied_tag.update!(name: "cru3-r3-renamed", slug: "cru3-r3-renamed")
    expect(Tag.find_by_name(retired_slug)).to be_nil
    expect(Tag.find_by(slug: retired_slug)).to be_nil
    paths = ["/tags/#{retired_slug}/#{denied_tag.id}", "/tags/retired-allowed/#{allowed_tag.id}"]
    paths
      .zip([denied_tag, allowed_tag])
      .each do |path, tag|
        destination = redirect_destination(path, status: 301)
        expect(Discourse.route_for("#{destination}.json")).to include(
          controller: "tags",
          tag_id: tag.id.to_s,
        )
      end

    expect_concealed_paths([paths]) { restrict_urls("forum_content") }
  end

  it "[cr-u3] ListSiteSettings conceals absolute and relative numeric tag name fallback URLs under forum_content" do
    denied_tag.update!(name: "98510001", slug: "98510001")
    allowed_tag.update!(name: "98510002", slug: "98510002")
    paths =
      [denied_tag, allowed_tag].map do |tag|
        expect(Tag.find_by(id: tag.name)).to be_nil
        expect(Tag.find_by_name(tag.name)).to eq(tag)
        path = "/tag/#{tag.name}.json"
        expect(Discourse.route_for(path)).to include(controller: "tags", tag_id: tag.name)
        path
      end

    expect_concealed_paths([paths]) { restrict_urls("forum_content") }
  end

  it "[cr-u3] ListSiteSettings conceals absolute and relative redirect route URLs by their restricted destination under forum_content" do
    paths =
      [denied_category, allowed_category].map do |category|
        path = "/category/#{category.slug}/#{category.id}"
        expect(Discourse.route_for(path)).to include(controller: "categories", action: "redirect")
        destination = redirect_destination(path, status: 302)
        expect(
          Category.find_by_slug_path_with_id(
            Discourse.route_for(destination).fetch(:category_slug_path_with_id),
          ),
        ).to eq(category)
        path
      end

    expect_concealed_paths([paths]) { restrict_urls("forum_content") }
  end

  shared_examples "permalink setting URLs" do |rule_kind|
    it "[cr-u3] ListSiteSettings conceals absolute and relative permalink URLs by their restricted target under #{rule_kind}" do
      topic = restricted_topic(rule_kind)
      post = Fabricate(:post, id: 96_510_001, topic:, user: admin)
      targets = [[topic, allowed_topic], [post, allowed_post]]
      targets += [[denied_category, allowed_category], [denied_tag, allowed_tag]] if rule_kind ==
        "forum_content"
      paths =
        targets.each_with_index.map do |records, index|
          records.each_with_index.map do |record, side|
            association = record.class.name.underscore.to_sym
            permalink =
              Permalink.create!(:url => "cru3-r3-archive/#{index}/#{side}", association => record)
            path = "/#{permalink.url}"
            expect(Discourse.route_for(path)).to include(controller: "permalinks", action: "show")
            expect(Permalink.find_by_url(path).target_url).to eq(record.relative_url)
            expect(admin.guardian.can_see_permalink_target?(permalink)).to eq(true)
            path
          end
        end

      expect_concealed_paths(paths) { restrict_urls(rule_kind) }
    end
  end

  shared_examples "unrecognized setting URLs" do |rule_kind|
    it "[cr-u3] ListSiteSettings conceals absolute and relative unrecognized local URLs under #{rule_kind} and keeps recognized allowed URLs" do
      unrecognized_path = "/cru3-r3-browser-only/opaque-reference"
      recognized_path = "/t/#{allowed_topic.slug}/#{allowed_topic.id}"
      expect(Discourse.route_for(unrecognized_path)).to be_nil
      expect(Permalink.find_by_url(unrecognized_path)).to be_nil
      expect(Discourse.route_for(recognized_path)).to include(
        controller: "topics",
        topic_id: allowed_topic.id.to_s,
      )

      expect_concealed_paths([[unrecognized_path, recognized_path]]) { restrict_urls(rule_kind) }
    end
  end

  include_examples "permalink setting URLs", "forum_content"
  include_examples "permalink setting URLs", "private_messages"
  include_examples "unrecognized setting URLs", "forum_content"
  include_examples "unrecognized setting URLs", "private_messages"
end
