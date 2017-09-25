require 'rails_helper'

describe EmbedController do

  let(:host) { "eviltrout.com" }
  let(:embed_url) { "http://eviltrout.com/2013/02/10/why-discourse-uses-emberjs.html" }
  let(:discourse_username) { "eviltrout" }

  it "is 404 without an embed_url" do
    get '/embed/comments'
    expect(response.body).to match(I18n.t('embed.error'))
  end

  it "raises an error with a missing host" do
    get '/embed/comments', params: { embed_url: embed_url }
    expect(response.body).to match(I18n.t('embed.error'))
  end

  context "by topic id" do
    let(:headers) { { 'REFERER' => 'http://eviltrout.com/some-page' } }

    before do
      Fabricate(:embeddable_host)
    end

    it "allows a topic to be embedded by id" do
      topic = Fabricate(:topic)
      get '/embed/comments', params: { topic_id: topic.id }, headers: headers
      expect(response).to be_success
    end
  end

  context "#info" do
    context "without api key" do
      it "fails" do
        get '/embed/info.json'
        expect(response.body).to match(I18n.t('embed.error'))
      end
    end

    context "with api key" do

      let(:api_key) { ApiKey.create_master_key }

      context "with valid embed url" do
        let(:topic_embed) { Fabricate(:topic_embed, embed_url: embed_url) }

        it "returns information about the topic" do
          get '/embed/info.json',
            params: { embed_url: topic_embed.embed_url, api_key: api_key.key, api_username: "system" }

          json = JSON.parse(response.body)
          expect(json['topic_id']).to eq(topic_embed.topic.id)
          expect(json['post_id']).to eq(topic_embed.post.id)
          expect(json['topic_slug']).to eq(topic_embed.topic.slug)
        end
      end

      context "without invalid embed url" do
        it "returns error response" do
          get '/embed/info.json',
            params: { embed_url: "http://nope.com", api_key: api_key.key, api_username: "system" }

          json = JSON.parse(response.body)
          expect(json["error_type"]).to eq("not_found")
        end
      end
    end
  end

  context "with a host" do
    let!(:embeddable_host) { Fabricate(:embeddable_host) }

    it "raises an error with no referer" do
      get '/embed/comments', params: { embed_url: embed_url }
      expect(response.body).to match(I18n.t('embed.error'))
    end

    context "success" do
      let(:headers) { { 'REFERER' => embed_url } }

      after do
        expect(response).to be_success
        expect(response.headers['X-Frame-Options']).to eq("ALLOWALL")
      end

      it "tells the topic retriever to work when no previous embed is found" do
        TopicEmbed.expects(:topic_id_for_embed).returns(nil)
        retriever = mock
        TopicRetriever.expects(:new).returns(retriever)
        retriever.expects(:retrieve)
        get '/embed/comments', params: { embed_url: embed_url }, headers: headers
      end

      it "displays the right view" do
        topic_embed = Fabricate(:topic_embed, embed_url: embed_url)

        get '/embed/comments', params: { embed_url: embed_url }, headers: headers

        expect(response.body).to match(I18n.t('embed.start_discussion'))
      end

      it "creates a topic view when a topic_id is found" do
        topic_embed = Fabricate(:topic_embed, embed_url: embed_url)
        post = Fabricate(:post, topic: topic_embed.topic)

        get '/embed/comments', params: { embed_url: embed_url }, headers: headers

        expect(response.body).to match(I18n.t('embed.continue'))
        expect(response.body).to match(post.cooked)
      end

      it "provides the topic retriever with the discourse username when provided" do
        TopicRetriever.expects(:new).with(embed_url, has_entry(author_username: discourse_username))

        get '/embed/comments',
          params: { embed_url: embed_url, discourse_username: discourse_username },
          headers: headers
      end

    end
  end

  context "with multiple hosts" do
    before do
      Fabricate(:embeddable_host)
      Fabricate(:embeddable_host, host: 'http://discourse.org')
      Fabricate(:embeddable_host, host: 'https://example.com/1234', class_name: 'example')
    end

    context "success" do
      it "works with the first host" do
        get '/embed/comments',
          params: { embed_url: embed_url },
          headers: { 'REFERER' => "http://eviltrout.com/wat/1-2-3.html" }

        expect(response).to be_success
      end

      it "works with the second host" do
        get '/embed/comments',
          params: { embed_url: embed_url },
          headers: { 'REFERER' => "http://eviltrout.com/wat/1-2-3.html" }

        expect(response).to be_success
      end

      it "works with a host with a path" do
        get '/embed/comments',
          params: { embed_url: embed_url },
          headers: { 'REFERER' => "https://example.com/some-other-path" }

        expect(response).to be_success
      end

      it "contains custom class name" do
        get '/embed/comments',
          params: { embed_url: embed_url },
          headers: { 'REFERER' => "https://example.com/some-other-path" }

        expect(response.body).to match('class="example"')
      end

      it "doesn't work with a made up host" do
        get '/embed/comments',
          params: { embed_url: embed_url },
          headers: { 'REFERER' => "http://codinghorror.com/invalid-url" }

        expect(response.body).to match(I18n.t('embed.error'))
      end
    end
  end
end
