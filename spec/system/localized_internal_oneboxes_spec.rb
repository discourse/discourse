# frozen_string_literal: true

describe "Localized internal oneboxes" do
  fab!(:japanese_user) { Fabricate(:user, locale: "ja", refresh_auto_groups: true) }

  fab!(:linked_topic) { Fabricate(:topic, title: "Sun Tzu's strategies", locale: "en") }
  fab!(:linked_post) do
    Fabricate(
      :post,
      topic: linked_topic,
      post_number: 1,
      locale: "en",
      raw: "Subdue the enemy without fighting.",
    )
  end

  fab!(:host_topic) { Fabricate(:topic, locale: "ja", title: "ホストトピックのタイトルですよ皆さんこんにちは") }
  fab!(:host_post) do
    Fabricate(:post, topic: host_topic, post_number: 1, locale: "ja", raw: "見てください")
  end

  let(:host_post_obj) { PageObjects::Components::Post.new(1) }

  before do
    SiteSetting.allow_user_locale = true
    SiteSetting.content_localization_enabled = true
    SiteSetting.content_localization_supported_locales = "en|ja"
    SiteSetting.content_localization_allowed_groups = Group::AUTO_GROUPS[:everyone]

    Fabricate(:topic_localization, topic: linked_topic, locale: "ja", title: "孫子の兵法")
    Fabricate(:post_localization, post: linked_post, locale: "ja", cooked: "<p>戦わずして勝つのが最善である</p>")

    # bake an internal onebox card (in its original English) into the host post,
    # matching what CookedPostProcessor would render for a same-site topic link
    host_post.update!(cooked: <<~HTML)
      <p>見てください</p>
      <aside class="quote" data-post="1" data-topic="#{linked_topic.id}">
        <div class="title">
          <div class="quote-controls"></div>
          <div class="quote-title__text-content"><a href="#{linked_topic.relative_url}">Sun Tzu's strategies</a></div>
        </div>
        <blockquote>Subdue the enemy without fighting.</blockquote>
      </aside>
    HTML

    TopicLink.create!(
      topic: host_topic,
      post: host_post,
      user: host_post.user,
      url: "#{Discourse.base_url}#{linked_topic.relative_url}",
      domain: Discourse.current_hostname,
      internal: true,
      quote: true,
      reflection: false,
      link_topic_id: linked_topic.id,
      link_post_id: linked_post.id,
    )
  end

  it "shows the onebox title and preview in the reader's language" do
    sign_in(japanese_user)
    visit("/t/#{host_topic.id}")

    expect(host_post_obj).to have_cooked_content("孫子の兵法")
    expect(host_post_obj).to have_cooked_content("戦わずして勝つ")
  end

  it "leaves the onebox in its original language when 'Show Original' is on" do
    japanese_user.user_option.update!(show_original_content: true)
    sign_in(japanese_user)
    visit("/t/#{host_topic.id}")

    expect(host_post_obj).to have_cooked_content("Sun Tzu's strategies")
  end
end
