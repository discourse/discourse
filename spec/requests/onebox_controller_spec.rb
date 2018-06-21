require 'rails_helper'

describe OneboxController do

  let(:url) { "http://google.com" }

  it "requires the user to be logged in" do
    get "/onebox.json", params: { url: url }
    expect(response.status).to eq(403)
  end

  describe "logged in" do
    let(:user) { Fabricate(:user) }
    let(:html) do
      html = <<~HTML
        <html>
        <head>
          <meta property="og:title" content="Onebox1">
          <meta property="og:description" content="this is bodycontent">
        </head>
        <body>
           <p>body</p>
        </body>
        <html>
      HTML
      html
    end

    let(:html2) do
      html = <<~HTML
        <html>
        <head>
          <meta property="og:title" content="Onebox2">
          <meta property="og:description" content="this is bodycontent">
        </head>
        <body>
           <p>body</p>
        </body>
        <html>
      HTML
      html
    end

    def bypass_limiting
      Oneboxer.onebox_previewed!(user.id)
    end

    before do
      sign_in(user)
    end

    it 'invalidates the cache if refresh is passed' do
      stub_request(:head, url)
      stub_request(:get, url).to_return(status: 200, body: html).then.to_raise

      bypass_limiting
      Rails.cache.delete("onebox__#{url}")
      get "/onebox.json", params: { url: url }
      expect(response.status).to eq(200)
      expect(response.body).to include("Onebox1")

      bypass_limiting
      stub_request(:get, url).to_return(status: 200, body: html2).then.to_raise
      get "/onebox.json", params: { url: url, refresh: 'true' }
      expect(response.status).to eq(200)
      expect(response.body).to include("Onebox2")
    end

    describe "cached onebox" do
      it "returns the cached onebox response in the body" do
        url = "http://noodle.com/"

        stub_request(:head, url)
        stub_request(:get, url).to_return(body: html).then.to_raise

        get "/onebox.json", params: { url: url, refresh: "true" }

        expect(response.status).to eq(200)
        expect(response.body).to include('Onebox1')
        expect(response.body).to include('bodycontent')

        get "/onebox.json", params: { url: url }
        expect(response.status).to eq(200)
        expect(response.body).to include('Onebox1')
        expect(response.body).to include('bodycontent')
      end
    end

    describe "only 1 outgoing preview per user" do
      it "returns 429" do
        Oneboxer.preview_onebox!(user.id)

        stub_request(:head, url)
        stub_request(:get, url).to_return(body: html).then.to_raise

        get "/onebox.json", params: { url: url, refresh: "true" }
        expect(response.status).to eq(429)
      end
    end

    describe "found onebox" do
      it 'returns the onebox response in the body' do
        stub_request(:head, url)
        stub_request(:get, url).to_return(body: html).then.to_raise
        get "/onebox.json", params: { url: url, refresh: "true" }

        expect(response.status).to eq(200)
        expect(response.body).to include("Onebox1")
      end
    end

    describe "missing onebox" do
      it "returns 404 if the onebox is nil" do
        stub_request(:head, url)
        stub_request(:get, url).to_return(body: nil).then.to_raise
        get "/onebox.json", params: { url: url, refresh: "true" }
        expect(response.response_code).to eq(404)
      end

      it "returns 404 if the onebox is an empty string" do
        stub_request(:head, url)
        stub_request(:get, url).to_return(body: " \t ").then.to_raise
        get "/onebox.json", params: { url: url, refresh: "true" }
        expect(response.response_code).to eq(404)
      end
    end

    describe "local onebox" do
      it 'does not cache local oneboxes' do
        post = create_post
        url = Discourse.base_url + post.url

        get "/onebox.json", params: { url: url, category_id: post.topic.category_id }
        expect(response.body).to include('blockquote')

        post.trash!

        get "/onebox.json", params: { url: url, category_id: post.topic.category_id }
        expect(response.body).not_to include('blockquote')
      end
    end

    it 'does not onebox when you have no permission on category' do
      post = create_post
      url = Discourse.base_url + post.url

      get "/onebox.json", params: { url: url, category_id: post.topic.category_id }
      expect(response.body).to include('blockquote')

      post.topic.category.set_permissions(staff: :full)
      post.topic.category.save

      get "/onebox.json", params: { url: url, category_id: post.topic.category_id }
      expect(response.body).not_to include('blockquote')
    end

    it 'does not allow onebox of PMs' do
      post = create_post(archetype: 'private_message', target_usernames: [user.username])
      url = Discourse.base_url + post.url

      get "/onebox.json", params: { url: url }
      expect(response.body).not_to include('blockquote')
    end

    it 'does not allow whisper onebox' do
      post = create_post
      whisper = create_post(topic_id: post.topic_id, post_type: Post.types[:whisper])
      url = Discourse.base_url + whisper.url

      get "/onebox.json", params: { url: url }
      expect(response.body).not_to include('blockquote')
    end

    it 'allows onebox to public topics/posts in PM' do
      post = create_post
      url = Discourse.base_url + post.url

      get "/onebox.json", params: { url: url }
      expect(response.body).to include('blockquote')
    end
  end
end
