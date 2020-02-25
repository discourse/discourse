# frozen_string_literal: true

require 'rails_helper'

describe Oneboxer do
  it "returns blank string for an invalid onebox" do
    stub_request(:head, "http://boom.com")
    stub_request(:get, "http://boom.com").to_return(body: "")

    expect(Oneboxer.preview("http://boom.com")).to eq("")
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
      expect(onebox).to include(PrettyText.avatar_img(replier.avatar_template, "tiny"))

      onebox = preview(public_moderator_action.url, user, public_category)
      expect(onebox).to include(public_moderator_action.excerpt)
      expect(onebox).to include(%{data-post="4"})
      expect(onebox).to include(PrettyText.avatar_img(staff.avatar_template, "tiny"))

      onebox = preview(public_reply.url, user, public_category, public_topic)
      expect(onebox).not_to include(public_topic.title)
      expect(onebox).to include(replier.avatar_template.sub("{size}", "40"))

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

  it "does not crawl blacklisted URLs" do
    SiteSetting.onebox_domains_blacklist = "git.*.com|bitbucket.com"
    url = 'https://github.com/discourse/discourse/commit/21b562852885f883be43032e03c709241e8e6d4f'
    stub_request(:head, 'https://discourse.org/').to_return(status: 302, body: "", headers: { location: url })

    expect(Oneboxer.external_onebox(url)[:onebox]).to be_empty
    expect(Oneboxer.external_onebox('https://discourse.org/')[:onebox]).to be_empty
  end

  it "does not consider ignore_redirects domains as blacklisted" do
    url = 'https://store.steampowered.com/app/271590/Grand_Theft_Auto_V/'
    stub_request(:head, url).to_return(status: 200, body: "", headers: {})
    stub_request(:get, url).to_return(status: 200, body: "", headers: {})

    expect(Oneboxer.external_onebox(url)[:onebox]).to be_present
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
end
