# frozen_string_literal: true

require_relative "server_support"

# rubocop:disable Discourse/NoIterationOverRSpecDefinitions

describe DiscourseMcp::Server do
  include McpContentRestrictionsUnit3::ServerSupport

  let(:denied_category) { Fabricate(:category, id: 102_620_001) }
  let(:allowed_category) { Fabricate(:category, id: 102_620_002) }
  let(:denied_topic) do
    Fabricate(:topic, id: 103_620_001, category: denied_category, external_id: "review-two-denied")
  end
  let(:allowed_topic) do
    Fabricate(
      :topic,
      id: 103_620_002,
      category: allowed_category,
      external_id: "review-two-allowed",
    )
  end

  def review2_setting(url)
    SiteSetting.tos_url = url
    response = rpc("discourse_list_site_settings", "names" => ["tos_url"])
    expect_usable(response)
    payloads(response).map { |payload| payload.fetch("site_settings").sole }
  end

  def review2_expect_kept(url)
    review2_setting(url).each do |setting|
      expect(setting).to include("value" => url), "allowed URL redacted: #{url}"
      expect(setting["redacted"]).not_to eq(true)
    end
  end

  def review2_expect_hidden(url)
    review2_setting(url).each do |setting|
      expect(setting).to include("value" => nil, "default" => nil, "redacted" => true),
      "restricted URL retained: #{url}"
    end
  end

  def review2_get(path)
    client = ActionDispatch::Integration::Session.new(Rails.application)
    client.host! Discourse.current_hostname
    client.get(path, headers: { "ACCEPT" => "application/json" })
    client.response
  end

  def review2_expect_redirect(path, destination)
    response = review2_get(path)
    expect(response.status).to eq(301), response.body
    expect(response.headers.fetch("Location")).to eq("#{Discourse.base_url}#{destination}")
  end

  before do
    Fabricate(:post, topic: denied_topic)
    Fabricate(:post, topic: allowed_topic)
  end

  %i[restricted allowed].each do |direction|
    it "[cr-u3] conceals full query permalink URLs for #{direction} destinations" do
      path = "/review-two-query?view=seasonal"
      target, decoy =
        direction == :restricted ? [denied_topic, allowed_topic] : [allowed_topic, denied_topic]
      Permalink.create!(url: path, topic: target)
      Permalink.create!(url: "/review-two-query", topic: decoy)
      review2_expect_redirect(path, target.relative_url)
      review2_expect_redirect("/review-two-query", decoy.relative_url)
      [path, "#{Discourse.base_url}#{path}"].each { |url| review2_expect_kept(url) }
      forum_rule(denied_categories: [denied_category.id])
      aggregate_failures do
        [path, "#{Discourse.base_url}#{path}"].each { |url| review2_expect_hidden(url) }
      end
    end
  end

  %i[restricted allowed].each do |direction|
    it "[cr-u3] conceals a live #{direction} route with a conflicting permalink" do
      target, decoy =
        direction == :restricted ? [denied_topic, allowed_topic] : [allowed_topic, denied_topic]
      path = "/t/#{target.id}.json"
      Permalink.create!(url: path, topic: decoy)
      expect(Permalink.find_by_url(path).topic).to eq(decoy)
      response = review2_get(path)
      expect(response.status).to eq(200), response.body
      expect(JSON.parse(response.body)).to include("id" => target.id)
      [path, "#{Discourse.base_url}#{path}"].each { |url| review2_expect_kept(url) }
      forum_rule(denied_categories: [denied_category.id])
      aggregate_failures do
        [path, "#{Discourse.base_url}#{path}"].each { |url| review2_expect_hidden(url) }
      end
    end
  end

  it "[cr-u3] conceals query-sensitive permalink chains including allowed chains" do
    paths =
      [denied_topic, allowed_topic].each_with_index.map do |topic, index|
        final = "/review-two-chain/#{index}?view=seasonal"
        Permalink.create!(url: final, topic: topic)
        Permalink.create!(
          url: "/review-two-chain/#{index}",
          topic: index.zero? ? allowed_topic : denied_topic,
        )
        first = "/review-two-chain-start/#{index}"
        Permalink.create!(url: first, external_url: final)
        review2_expect_redirect(first, final)
        review2_expect_redirect(final, topic.relative_url)
        first
      end
    forum_rule(denied_categories: [denied_category.id])
    aggregate_failures do
      ["", Discourse.base_url].each do |base|
        review2_expect_hidden("#{base}#{paths.last}")
        review2_expect_hidden("#{base}#{paths.first}")
      end
    end
  end

  it "[cr-u3] conceals topic external identifiers including allowed topics and user profiles" do
    paths =
      [denied_topic, allowed_topic].map do |topic|
        path = "/t/external_id/#{topic.external_id}"
        expect(Rails.application.routes.recognize_path(path)).to include(
          controller: "topics",
          action: "show_by_external_id",
          external_id: topic.external_id,
        )
        review2_expect_redirect(path, "#{topic.relative_url}.json")
        path
      end
    profile = "/u/#{admin.username}"
    expect(Rails.application.routes.recognize_path(profile)).to include(controller: "users")
    forum_rule(denied_categories: [denied_category.id])
    aggregate_failures do
      ["", Discourse.base_url].each do |base|
        review2_expect_hidden("#{base}#{profile}")
        review2_expect_hidden("#{base}#{paths.last}")
        review2_expect_hidden("#{base}#{paths.first}")
      end
    end
  end

  it "[cr-u3] conceals unjudged engine event identifiers and an allowed core topic URL" do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    events =
      [denied_topic, allowed_topic].each_with_index.map do |topic, index|
        event_post = Fabricate(:post, id: 104_620_001 + index, topic: topic)
        Fabricate(:event, post: event_post)
      end
    paths =
      events.map do |event|
        path = "/discourse-post-event/events/#{event.id}.json"
        expect(Rails.application.routes.recognize_path(path)).to include(
          controller: "discourse_events/events",
          id: event.id.to_s,
        )
        response = review2_get(path)
        expect(response.status).to eq(200), response.body
        expect(JSON.parse(response.body).fetch("event")).to include("id" => event.id)
        path
      end
    core_path = "/t/#{allowed_topic.id}.json"
    expect(Rails.application.routes.recognize_path(core_path)).to include(
      controller: "topics",
      id: allowed_topic.id.to_s,
    )
    response = review2_get(core_path)
    expect(response.status).to eq(200), response.body
    expect(JSON.parse(response.body)).to include("id" => allowed_topic.id)
    ["", Discourse.base_url].each do |base|
      [*paths, core_path].each { |path| review2_expect_kept("#{base}#{path}") }
    end
    forum_rule(denied_categories: [denied_category.id])
    aggregate_failures do
      ["", Discourse.base_url].each do |base|
        review2_expect_hidden("#{base}#{core_path}")
        paths.each { |path| review2_expect_hidden("#{base}#{path}") }
      end
    end
  end
end

# rubocop:enable Discourse/NoIterationOverRSpecDefinitions
