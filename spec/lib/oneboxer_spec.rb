# frozen_string_literal: true

require 'rails_helper'

describe Oneboxer do
  def response(file)
    file = File.join("spec", "fixtures", "onebox", "#{file}.response")
    File.exist?(file) ? File.read(file) : ""
  end

  it "returns blank string for an invalid onebox" do
    stub_request(:head, "http://boom.com")
    stub_request(:get, "http://boom.com").to_return(body: "")

    expect(Oneboxer.preview("http://boom.com", invalidate_oneboxes: true)).to include("Sorry, we were unable to generate a preview for this web page")
    expect(Oneboxer.onebox("http://boom.com")).to eq("")
  end

  describe "#invalidate" do
    let(:url) { "http://test.com" }
    it "clears the cached preview for the onebox URL and the failed URL cache" do
      Discourse.cache.write(Oneboxer.onebox_cache_key(url), "test")
      Discourse.cache.write(Oneboxer.onebox_failed_cache_key(url), true)
      Oneboxer.invalidate(url)
      expect(Discourse.cache.read(Oneboxer.onebox_cache_key(url))).to eq(nil)
      expect(Discourse.cache.read(Oneboxer.onebox_failed_cache_key(url))).to eq(nil)
    end
  end

  context "local oneboxes" do

    def link(url)
      url = "#{Discourse.base_url}#{url}"
      %{<a href="#{url}">#{url}</a>}
    end

    def preview(url, user = nil, category = nil, topic = nil)
      Oneboxer.preview("#{Discourse.base_url}#{url}",
        user_id: user&.id,
        category_id: category&.id,
        topic_id: topic&.id).to_s
    end

    it "links to a topic/post" do
      staff = Fabricate(:user)
      Group[:staff].add(staff)

      secured_category = Fabricate(:category)
      secured_category.permissions = { staff: :full }
      secured_category.save!

      replier = Fabricate(:user)

      public_post             = Fabricate(:post, raw: "This post has an emoji :+1:")
      public_topic            = public_post.topic
      public_reply            = Fabricate(:post, topic: public_topic, post_number: 2, user: replier)
      public_hidden           = Fabricate(:post, topic: public_topic, post_number: 3, hidden: true)
      public_moderator_action = Fabricate(:post, topic: public_topic, post_number: 4, user: staff, post_type: Post.types[:moderator_action])

      user = public_post.user
      public_category = public_topic.category

      secured_topic = Fabricate(:topic, user: staff, category: secured_category)
      secured_post  = Fabricate(:post, user: staff, topic: secured_topic)
      secured_reply = Fabricate(:post, user: staff, topic: secured_topic, post_number: 2)

      expect(preview(public_topic.relative_url, user, public_category)).to include(public_topic.title)
      onebox = preview(public_post.url, user, public_category)
      expect(onebox).to include(public_topic.title)
      expect(onebox).to include("/images/emoji/")

      onebox = preview(public_reply.url, user, public_category)
      expect(onebox).to include(public_reply.excerpt)
      expect(onebox).to include(%{data-post="2"})
      expect(onebox).to include(PrettyText.avatar_img(replier.avatar_template_url, "tiny"))

      short_url = "#{Discourse.base_path}/t/#{public_topic.id}"
      expect(preview(short_url, user, public_category)).to include(public_topic.title)

      onebox = preview(public_moderator_action.url, user, public_category)
      expect(onebox).to include(public_moderator_action.excerpt)
      expect(onebox).to include(%{data-post="4"})
      expect(onebox).to include(PrettyText.avatar_img(staff.avatar_template_url, "tiny"))

      onebox = preview(public_reply.url, user, public_category, public_topic)
      expect(onebox).not_to include(public_topic.title)
      expect(onebox).to include(replier.avatar_template_url.sub("{size}", "40"))

      expect(preview(public_hidden.url, user, public_category)).to match_html(link(public_hidden.url))
      expect(preview(secured_topic.relative_url, user, public_category)).to match_html(link(secured_topic.relative_url))
      expect(preview(secured_post.url, user, public_category)).to match_html(link(secured_post.url))
      expect(preview(secured_reply.url, user, public_category)).to match_html(link(secured_reply.url))

      expect(preview(public_topic.relative_url, user, secured_category)).to match_html(link(public_topic.relative_url))
      expect(preview(public_reply.url, user, secured_category)).to match_html(link(public_reply.url))
      expect(preview(secured_post.url, user, secured_category)).to match_html(link(secured_post.url))
      expect(preview(secured_reply.url, user, secured_category)).to match_html(link(secured_reply.url))

      expect(preview(public_topic.relative_url, staff, secured_category)).to include(public_topic.title)
      expect(preview(public_post.url, staff, secured_category)).to include(public_topic.title)
      expect(preview(public_reply.url, staff, secured_category)).to include(public_reply.excerpt)
      expect(preview(public_hidden.url, staff, secured_category)).to match_html(link(public_hidden.url))
      expect(preview(secured_topic.relative_url, staff, secured_category)).to include(secured_topic.title)
      expect(preview(secured_post.url, staff, secured_category)).to include(secured_topic.title)
      expect(preview(secured_reply.url, staff, secured_category)).to include(secured_reply.excerpt)
      expect(preview(secured_reply.url, staff, secured_category, secured_topic)).not_to include(secured_topic.title)
    end

    it "links to an user profile" do
      user = Fabricate(:user)

      expect(preview("/u/does-not-exist")).to match_html(link("/u/does-not-exist"))
      expect(preview("/u/#{user.username}")).to include(user.name)
    end

    it "should respect enable_names site setting" do
      user = Fabricate(:user)

      SiteSetting.enable_names = true
      expect(preview("/u/#{user.username}")).to include(user.name)
      SiteSetting.enable_names = false
      expect(preview("/u/#{user.username}")).not_to include(user.name)
    end

    it "links to an upload" do
      path = "/uploads/default/original/3X/e/8/e8fcfa624e4fb6623eea57f54941a58ba797f14d"

      expect(preview("#{path}.pdf")).to match_html(link("#{path}.pdf"))
      expect(preview("#{path}.MP3")).to include("<audio ")
      expect(preview("#{path}.mov")).to include("<video ")
    end

    it "strips HTML from user profile location" do
      user = Fabricate(:user)
      profile = user.reload.user_profile

      expect(preview("/u/#{user.username}")).not_to include("<span class=\"location\">")

      profile.update!(
        location: "<img src=x onerror=alert(document.domain)>",
      )

      expect(preview("/u/#{user.username}")).to include("<span class=\"location\">")
      expect(preview("/u/#{user.username}")).not_to include("<img src=x")

      profile.update!(
        location: "Thunderland",
      )

      expect(preview("/u/#{user.username}")).to include("Thunderland")
    end
  end

  context ".onebox_raw" do
    it "should escape the onebox URL before processing" do
      post = Fabricate(:post, raw: Discourse.base_url + "/new?'class=black")
      cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
      cpp.post_process_oneboxes
      expect(cpp.html).to eq("<p><a href=\"#{Discourse.base_url}/new?%27class=black\">http://test.localhost/new?%27class=black</a></p>")
    end
  end

  context ".external_onebox" do
    html = <<~HTML
      <html>
      <head>
        <meta property="og:title" content="Cats">
        <meta property="og:description" content="Meow">
      </head>
      <body>
         <p>body</p>
      </body>
      <html>
    HTML

    context "blacklisted domains" do

      it "does not return a onebox if redirect uri final destination is in blacklist" do
        SiteSetting.blocked_onebox_domains = "kitten.com"

        stub_request(:get, "http://cat.com/meow").to_return(status: 301, body: "", headers: { "location" => "https://kitten.com" })
        stub_request(:head, "http://cat.com/meow").to_return(status: 301, body: "", headers: { "location" => "https://kitten.com" })

        stub_request(:get, "https://kitten.com").to_return(status: 200, body: html, headers: {})
        stub_request(:head, "https://kitten.com").to_return(status: 200, body: "", headers: {})

        expect(Oneboxer.external_onebox("http://cat.com/meow")[:onebox]).to be_empty
        expect(Oneboxer.external_onebox("https://kitten.com")[:onebox]).to be_empty
      end

      it "returns onebox if 'midway redirect' is blocked but final redirect uri is not blocked" do
        SiteSetting.blocked_onebox_domains = "middle.com"

        stub_request(:get, "https://cat.com/start").to_return(status: 301, body: "a", headers: { "location" => "https://middle.com/midway" })
        stub_request(:head, "https://cat.com/start").to_return(status: 301, body: "a", headers: { "location" => "https://middle.com/midway" })

        stub_request(:head, "https://middle.com/midway").to_return(status: 301, body: "b", headers: { "location" => "https://cat.com/end" })

        stub_request(:get, "https://cat.com/end").to_return(status: 200, body: html)
        stub_request(:head, "https://cat.com/end").to_return(status: 200, body: "", headers: {})

        expect(Oneboxer.external_onebox("https://cat.com/start")[:onebox]).to be_present
      end
    end

    it "censors external oneboxes" do
      Fabricate(:watched_word, action: WatchedWord.actions[:censor], word: "bad word")

      url = 'https://example.com/'
      stub_request(:any, url).to_return(status: 200, body: <<~HTML, headers: {})
      <html>
      <head>
        <meta property="og:title" content="title with bad word">
        <meta property="og:description" content="description with bad word">
      </head>
      <body>
        <p>content with bad word</p>
      </body>
      <html>
      HTML

      onebox = Oneboxer.external_onebox(url)
      expect(onebox[:onebox]).to include('title with')
      expect(onebox[:onebox]).not_to include('bad word')
      expect(onebox[:preview]).to include('title with')
      expect(onebox[:preview]).not_to include('bad word')
    end

    it "returns onebox" do
      SiteSetting.blocked_onebox_domains = "not.me"

      stub_request(:get, "https://its.me").to_return(status: 200, body: html)
      stub_request(:head, "https://its.me").to_return(status: 200, body: "", headers: {})

      expect(Oneboxer.external_onebox("https://its.me")[:onebox]).to be_present
    end
  end

  it "uses the Onebox custom user agent on specified hosts" do
    SiteSetting.force_custom_user_agent_hosts = "http://codepen.io|https://video.discourse.org/"
    url = 'https://video.discourse.org/presentation.mp4'

    stub_request(:head, url).to_return(status: 403, body: "", headers: {})
    stub_request(:get, url).to_return(status: 403, body: "", headers: {})
    stub_request(:head, url).with(headers: { "User-Agent" => Onebox.options.user_agent }).to_return(status: 200, body: "", headers: {})
    stub_request(:get, url).with(headers: { "User-Agent" => Onebox.options.user_agent }).to_return(status: 200, body: "", headers: {})

    expect(Oneboxer.preview(url, invalidate_oneboxes: true)).to be_present
  end

  context "with youtube stub" do
    let(:html) do
      <<~HTML
        <html>
        <head>
          <meta property="og:title" content="Onebox1">
          <meta property="og:description" content="this is bodycontent">
          <meta property="og:image" content="https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg">
        </head>
        <body>
           <p>body</p>
        </body>
        <html>
      HTML
    end

    before do
      stub_request(:any, "https://www.youtube.com/watch?v=dQw4w9WgXcQ").to_return(status: 200, body: html)
      stub_request(:any, "https://www.youtube.com/embed/dQw4w9WgXcQ").to_return(status: 403, body: nil)
    end

    it "allows restricting engines based on the allowed_onebox_iframes setting" do
      output = Oneboxer.onebox("https://www.youtube.com/watch?v=dQw4w9WgXcQ", invalidate_oneboxes: true)
      expect(output).to include("<iframe") # Regular youtube onebox

      # Disable all onebox iframes:
      SiteSetting.allowed_onebox_iframes = ""
      output = Oneboxer.onebox("https://www.youtube.com/watch?v=dQw4w9WgXcQ", invalidate_oneboxes: true)

      expect(output).not_to include("<iframe") # Generic onebox
      expect(output).to include("allowlistedgeneric")

      # Just enable youtube:
      SiteSetting.allowed_onebox_iframes = "https://www.youtube.com"
      output = Oneboxer.onebox("https://www.youtube.com/watch?v=dQw4w9WgXcQ", invalidate_oneboxes: true)
      expect(output).to include("<iframe") # Regular youtube onebox
    end
  end

  it "allows iframes from generic sites via the allowed_iframes setting" do
    allowlisted_body = '<html><head><link rel="alternate" type="application/json+oembed" href="https://allowlist.ed/iframes.json" />'
    blocklisted_body = '<html><head><link rel="alternate" type="application/json+oembed" href="https://blocklist.ed/iframes.json" />'

    allowlisted_oembed = {
      type: "rich",
      height: "100",
      html: "<iframe src='https://ifram.es/foo/bar'></iframe>"
    }

    blocklisted_oembed = {
      type: "rich",
      height: "100",
      html: "<iframe src='https://malicious/discourse.org/'></iframe>"
    }

    stub_request(:any, "https://blocklist.ed/iframes").to_return(status: 200, body: blocklisted_body)
    stub_request(:any, "https://blocklist.ed/iframes.json").to_return(status: 200, body: blocklisted_oembed.to_json)

    stub_request(:any, "https://allowlist.ed/iframes").to_return(status: 200, body: allowlisted_body)
    stub_request(:any, "https://allowlist.ed/iframes.json").to_return(status: 200, body: allowlisted_oembed.to_json)

    SiteSetting.allowed_iframes = "discourse.org|https://ifram.es"

    expect(Oneboxer.onebox("https://blocklist.ed/iframes", invalidate_oneboxes: true)).to be_empty
    expect(Oneboxer.onebox("https://allowlist.ed/iframes", invalidate_oneboxes: true)).to match("iframe src")
  end

  context 'missing attributes' do
    before do
      stub_request(:head, url)
    end

    let(:url) { "https://example.com/fake-url/" }

    it 'handles a missing description' do
      stub_request(:get, url).to_return(body: response("missing_description"))
      expect(Oneboxer.preview(url, invalidate_oneboxes: true)).to include("could not be found: description")
    end

    it 'handles a missing description and image' do
      stub_request(:get, url).to_return(body: response("missing_description_and_image"))
      expect(Oneboxer.preview(url, invalidate_oneboxes: true)).to include("could not be found: description, image")
    end

    it 'handles a missing image' do
      # Note: If the only error is a missing image, we shouldn't return an error
      stub_request(:get, url).to_return(body: response("missing_image"))
      expect(Oneboxer.preview(url, invalidate_oneboxes: true)).not_to include("could not be found")
    end

    it 'video with missing description returns a placeholder' do
      stub_request(:get, url).to_return(body: response("video_missing_description"))
      expect(Oneboxer.preview(url, invalidate_oneboxes: true)).to include("onebox-placeholder-container")
    end
  end

  context 'instagram' do
    it 'providing a token should attempt to use new endpoint' do
      url = "https://www.instagram.com/p/CHLkBERAiLa"
      access_token = 'abc123'

      SiteSetting.facebook_app_access_token = access_token

      stub_request(:head, url)
      stub_request(:get, "https://graph.facebook.com/v9.0/instagram_oembed?url=#{url}&access_token=#{access_token}").to_return(body: response("instagram_new"))

      expect(Oneboxer.preview(url, invalidate_oneboxes: true)).to include('placeholder-icon image')
    end

    it 'unconfigured token should attempt to use old endpoint' do
      url = "https://www.instagram.com/p/CHLkBERAiLa"
      stub_request(:head, url)
      stub_request(:get, "https://api.instagram.com/oembed/?url=#{url}").to_return(body: response("instagram_old"))

      expect(Oneboxer.preview(url, invalidate_oneboxes: true)).to include('placeholder-icon image')
    end

    it 'renders result using an iframe' do
      url = "https://www.instagram.com/p/CHLkBERAiLa"
      stub_request(:head, url)
      stub_request(:get, "https://api.instagram.com/oembed/?url=#{url}").to_return(body: response("instagram_old"))

      expect(Oneboxer.onebox(url, invalidate_oneboxes: true)).to include('iframe')
    end
  end

  describe '#apply' do
    it 'generates valid HTML' do
      raw = "Before Onebox\nhttps://example.com\nAfter Onebox"
      cooked = Oneboxer.apply(PrettyText.cook(raw)) { '<div>onebox</div>' }
      doc = Nokogiri::HTML5::fragment(cooked.to_html)
      expect(doc.to_html).to match_html <<~HTML
        <p>Before Onebox</p>
        <div>onebox</div>
        <p>After Onebox</p>
      HTML

      raw = "Before Onebox\nhttps://example.com\nhttps://example.com\nAfter Onebox"
      cooked = Oneboxer.apply(PrettyText.cook(raw)) { '<div>onebox</div>' }
      doc = Nokogiri::HTML5::fragment(cooked.to_html)
      expect(doc.to_html).to match_html <<~HTML
        <p>Before Onebox</p>
        <div>onebox</div>
        <div>onebox</div>
        <p>After Onebox</p>
      HTML
    end

    it 'does keeps SVGs valid' do
      raw = "Onebox\n\nhttps://example.com"
      cooked = PrettyText.cook(raw)
      cooked = Oneboxer.apply(Loofah.fragment(cooked)) { '<div><svg><path></path></svg></div>' }
      doc = Nokogiri::HTML5::fragment(cooked.to_html)
      expect(doc.to_html).to match_html <<~HTML
        <p>Onebox</p>
        <div><svg><path></path></svg></div>
      HTML
    end
  end

  describe '#force_get_hosts' do
    before do
      SiteSetting.cache_onebox_response_body_domains = "example.net|example.com|example.org"
    end

    it "includes Amazon sites" do
      expect(Oneboxer.force_get_hosts).to include('https://www.amazon.ca')
    end

    it "includes cache_onebox_response_body_domains" do
      expect(Oneboxer.force_get_hosts).to include('https://www.example.com')
    end
  end

  context 'strategies' do
    it "has a 'default' strategy" do
      expect(Oneboxer.strategies.keys.first).to eq(:default)
    end

    it "has a strategy with overrides" do
      strategy = Oneboxer.strategies.keys[1]
      expect(Oneboxer.strategies[strategy].keys).not_to eq([])
    end

    context "using a non-default strategy" do
      let(:hostname) { "my.interesting.site" }
      let(:url) { "https://#{hostname}/cool/content" }
      let(:html) do
        <<~HTML
          <html>
          <head>
            <meta property="og:title" content="Page Title">
            <meta property="og:description" content="Here is some cool content">
          </head>
          <body>
             <p>body</p>
          </body>
          <html>
        HTML
      end

      before do
        stub_request(:head, url).to_return(status: 509)
        stub_request(:get, url).to_return(status: 200, body: html)
      end

      after do
        Oneboxer.clear_preferred_strategy!(hostname)
      end

      it "uses multiple strategies" do
        default_ordered = Oneboxer.strategies.keys
        custom_ordered = Oneboxer.ordered_strategies(hostname)
        expect(custom_ordered).to eq(default_ordered)

        expect(Oneboxer.preferred_strategy(hostname)).to eq(nil)
        expect(Oneboxer.preview(url, invalidate_oneboxes: true)).to include("Here is some cool content")

        custom_ordered = Oneboxer.ordered_strategies(hostname)

        expect(custom_ordered.count).to eq(default_ordered.count)
        expect(custom_ordered).not_to eq(default_ordered)

        expect(Oneboxer.preferred_strategy(hostname)).not_to eq(:default)
      end
    end
  end

  describe 'cache_onebox_response_body' do
    let(:html) do
      <<~HTML
        <html>
        <body>
           <p>cache me if you can</p>
        </body>
        <html>
      HTML
    end

    let(:url) { "https://www.example.com/my/great/content" }
    let(:url2) { "https://www.example2.com/my/great/content" }

    before do
      stub_request(:any, url).to_return(status: 200, body: html)
      stub_request(:any, url2).to_return(status: 200, body: html)

      SiteSetting.cache_onebox_response_body = true
      SiteSetting.cache_onebox_response_body_domains = "example.net|example.com|example.org"
    end

    it "caches when domain matches" do
      preview = Oneboxer.preview(url, invalidate_oneboxes: true)
      expect(Oneboxer.cached_response_body_exists?(url)).to eq(true)
      expect(Oneboxer.fetch_cached_response_body(url)).to eq(html)
    end

    it "ignores cache when domain not present" do
      preview = Oneboxer.preview(url2, invalidate_oneboxes: true)
      expect(Oneboxer.cached_response_body_exists?(url2)).to eq(false)
    end
  end

end
