# frozen_string_literal: true

RSpec.describe EmbedController do
  let(:embed_url) { "http://eviltrout.com/2013/02/10/why-discourse-uses-emberjs.html" }
  let(:embed_url_secure) { "https://eviltrout.com/2013/02/10/why-discourse-uses-emberjs.html" }
  let(:discourse_username) { "eviltrout" }

  fab!(:topic) { Fabricate(:topic) }

  describe "#info" do
    context "without api key" do
      it "fails" do
        get "/embed/info.json"

        expect(response.body).to match(I18n.t("embed.error"))
      end
    end

    context "with api key" do
      let(:api_key) { Fabricate(:api_key) }

      context "with valid embed url" do
        let(:topic_embed) { Fabricate(:topic_embed, embed_url: embed_url) }

        it "returns information about the topic" do
          get "/embed/info.json",
              params: {
                embed_url: topic_embed.embed_url,
              },
              headers: {
                HTTP_API_KEY: api_key.key,
                HTTP_API_USERNAME: "system",
              }

          expect(response.parsed_body["topic_id"]).to eq(topic_embed.topic.id)
          expect(response.parsed_body["post_id"]).to eq(topic_embed.post.id)
          expect(response.parsed_body["topic_slug"]).to eq(topic_embed.topic.slug)
        end
      end

      context "without invalid embed url" do
        it "returns error response" do
          get "/embed/info.json",
              params: {
                embed_url: "http://nope.com",
              },
              headers: {
                HTTP_API_KEY: api_key.key,
                HTTP_API_USERNAME: "system",
              }

          json = response.parsed_body
          expect(json["error_type"]).to eq("not_found")
        end
      end
    end
  end

  describe "#topics" do
    it "raises an error when not enabled" do
      get "/embed/topics?embed_id=de-1234"

      expect(response.status).to eq(400)
    end

    context "when enabled" do
      before { SiteSetting.embed_topics_list = true }

      it "raises an error with a weird id" do
        get "/embed/topics?discourse_embed_id=../asdf/-1234", headers: headers

        expect(response.status).to eq(400)
      end

      it "returns a list of topics" do
        get "/embed/topics?discourse_embed_id=de-1234",
            headers: {
              "REFERER" => "https://example.com/evil-trout",
            }

        expect(response.status).to eq(200)
        expect(response.headers["X-Frame-Options"]).to be_nil
        expect(response.body).to match("data-embed-id=\"de-1234\"")
        expect(response.body).to match("data-topic-id=\"#{topic.id}\"")
        expect(response.body).to match("data-referer=\"https://example.com/evil-trout\"")
      end

      it "returns a list of top topics" do
        good_topic = Fabricate(:topic, like_count: 1000, posts_count: 100)
        TopTopic.refresh!

        get "/embed/topics?discourse_embed_id=de-1234&top_period=yearly",
            headers: {
              "REFERER" => "https://example.com/evil-trout",
            }
        expect(response.status).to eq(200)
        expect(response.headers["X-Frame-Options"]).to be_nil
        expect(response.body).to match("data-embed-id=\"de-1234\"")
        expect(response.body).to match("data-topic-id=\"#{good_topic.id}\"")
        expect(response.body).not_to match("data-topic-id=\"#{topic.id}\"")
        expect(response.body).to match("data-referer=\"https://example.com/evil-trout\"")
      end

      it "returns a list of topics if the top_period is not valid" do
        good_topic = Fabricate(:topic, like_count: 1000, posts_count: 100)
        TopTopic.refresh!
        TopicQuery.any_instance.expects(:list_top_for).never

        get "/embed/topics?discourse_embed_id=de-1234&top_period=decadely",
            headers: {
              "REFERER" => "https://example.com/evil-trout",
            }

        expect(response.status).to eq(200)
        expect(response.headers["X-Frame-Options"]).to be_nil
        expect(response.body).to match("data-embed-id=\"de-1234\"")
        expect(response.body).to match("data-topic-id=\"#{good_topic.id}\"")
        expect(response.body).to match("data-topic-id=\"#{topic.id}\"")
        expect(response.body).to match("data-referer=\"https://example.com/evil-trout\"")
      end

      it "wraps the list in a custom class" do
        get "/embed/topics?discourse_embed_id=de-1234&embed_class=my-special-class",
            headers: {
              "REFERER" => "https://example.com/evil-trout",
            }

        expect(response.status).to eq(200)
        expect(response.headers["X-Frame-Options"]).to be_nil
        expect(response.body).to match("class='topics-list my-special-class'")
      end

      it "returns no referer if not supplied" do
        get "/embed/topics?discourse_embed_id=de-1234"

        expect(response.status).to eq(200)
        expect(response.body).to match("data-referer=\"\"")
      end

      it "returns * for the referer if `embed_any_origin` is set" do
        SiteSetting.embed_any_origin = true

        get "/embed/topics?discourse_embed_id=de-1234"

        expect(response.status).to eq(200)
        expect(response.body).to match("data-referer=\"\\*\"")
      end

      it "disallows indexing the embed topic list for Googlebot" do
        topic = Fabricate(:topic)
        get "/embed/topics?discourse_embed_id=de-1234", headers: {
          "REFERER' => "https://example.com/evil-trout"
        }
        expect(response.status).to eq(200)
        expect(response.headers["X-Robots-Tag"]).to match(/googlebot:noindex/)
      end      
    end
  end

  describe "#comments" do
    it "is 404 without an embed_url" do
      get "/embed/comments"

      expect(response.body).to match(I18n.t("embed.error"))
    end

    it "raises an error with a missing host" do
      get "/embed/comments", params: { embed_url: embed_url }

      expect(response.body).to match(I18n.t("embed.error"))
    end

    describe "by topic id" do
      fab!(:embeddable_host) { Fabricate(:embeddable_host) }

      it "allows a topic to be embedded by id" do
        get "/embed/comments",
            params: {
              topic_id: topic.id,
            },
            headers: {
              "REFERER" => "http://eviltrout.com/some-page",
            }

        expect(response.status).to eq(200)
      end
    end

    context "with a host" do
      fab!(:embeddable_host) { Fabricate(:embeddable_host) }

      before { Jobs.run_immediately! }

      it "doesn't raise an error with no referer" do
        get "/embed/comments", params: { embed_url: embed_url }

        expect(response.body).not_to match(I18n.t("embed.error"))
      end

      it "includes CSS from embedded_scss field" do
        theme = Fabricate(:theme)
        theme.set_default!

        ThemeField.create!(
          theme_id: theme.id,
          name: "embedded_scss",
          target_id: 0,
          type_id: 1,
          value: ".test-osama-15 { color: red }",
        )

        topic_embed = Fabricate(:topic_embed, embed_url: embed_url)
        post = Fabricate(:post, topic: topic_embed.topic)

        get "/embed/comments", params: { embed_url: embed_url }, headers: { "REFERER" => embed_url }

        html = Nokogiri::HTML5.fragment(response.body)
        get html.at("link[data-target=embedded_theme]").attribute("href").value
        expect(response.status).to eq(200)
        expect(response.body).to include(".test-osama-15")
      end

      it "includes HTML from embedded_header field" do
        theme = Fabricate(:theme)
        theme.set_default!

        ThemeField.create!(
          theme_id: theme.id,
          name: "embedded_header",
          target_id: 0,
          type_id: 0,
          value: "<strong class='custom-text'>hey there!</strong>\n",
        )

        topic_embed = Fabricate(:topic_embed, embed_url: embed_url)
        post = Fabricate(:post, topic: topic_embed.topic)

        get "/embed/comments", params: { embed_url: embed_url }, headers: headers

        html = Nokogiri::HTML5.fragment(response.body)
        custom_header = html.at(".custom-text")

        expect(custom_header.name).to eq("strong")
        expect(custom_header.text).to eq("hey there!")
      end

      context "with success" do
        it "tells the topic retriever to work when no previous embed is found" do
          TopicRetriever.any_instance.expects(:retrieve)

          get "/embed/comments",
              params: {
                embed_url: embed_url,
              },
              headers: {
                "REFERER" => embed_url,
              }

          expect(response.status).to eq(200)
          expect(response.headers["X-Frame-Options"]).to be_nil
        end

        it "displays the right view" do
          topic_embed = Fabricate(:topic_embed, embed_url: embed_url)

          get "/embed/comments",
              params: {
                embed_url: embed_url_secure,
              },
              headers: {
                "REFERER" => embed_url,
              }

          expect(response.status).to eq(200)
          expect(response.headers["X-Frame-Options"]).to be_nil
          expect(response.body).to match(I18n.t("embed.start_discussion"))
        end

        it "creates a topic view when a topic_id is found" do
          topic_embed = Fabricate(:topic_embed, embed_url: embed_url)

          post = Fabricate(:post, topic: topic_embed.topic)

          get "/embed/comments",
              params: {
                embed_url: embed_url,
              },
              headers: {
                "REFERER" => embed_url,
              }

          expect(response.status).to eq(200)
          expect(response.headers["X-Frame-Options"]).to be_nil
          expect(response.body).to match(I18n.t("embed.continue"))
          expect(response.body).to match(post.cooked)
          expect(response.body).to match("<span class='replies'>1 reply</span>")

          small_action = Fabricate(:small_action, topic: topic_embed.topic)

          get "/embed/comments",
              params: {
                embed_url: embed_url,
              },
              headers: {
                "REFERER" => embed_url,
              }

          expect(response.status).to eq(200)
          expect(response.headers["X-Frame-Options"]).to be_nil
          expect(response.body).not_to match("post-#{small_action.id}")
          expect(response.body).to match("<span class='replies'>1 reply</span>")
        end

        it "provides the topic retriever with the discourse username when provided" do
          TopicRetriever.any_instance.expects(:retrieve).returns(nil)

          get "/embed/comments",
              params: {
                embed_url: embed_url,
                discourse_username: discourse_username,
              },
              headers: {
                "REFERER" => embed_url,
              }

          expect(response.status).to eq(200)
          expect(response.headers["X-Frame-Options"]).to be_nil
        end
      end
    end

    context "with multiple hosts" do
      fab!(:embeddable_host_1) { Fabricate(:embeddable_host) }
      fab!(:embeddable_host_2) { Fabricate(:embeddable_host, host: "http://discourse.org") }
      fab!(:embeddable_host_3) do
        Fabricate(:embeddable_host, host: "https://example.com/1234", class_name: "example")
      end

      context "with success" do
        it "works with the first host" do
          get "/embed/comments",
              params: {
                embed_url: embed_url,
              },
              headers: {
                "REFERER" => "http://eviltrout.com/wat/1-2-3.html",
              }

          expect(response.status).to eq(200)
        end

        it "works with the second host" do
          get "/embed/comments",
              params: {
                embed_url: embed_url,
              },
              headers: {
                "REFERER" => "http://eviltrout.com/wat/1-2-3.html",
              }

          expect(response.status).to eq(200)
        end

        it "works with a host with a path" do
          get "/embed/comments",
              params: {
                embed_url: embed_url,
              },
              headers: {
                "REFERER" => "https://example.com/some-other-path",
              }

          expect(response.status).to eq(200)
        end

        it "contains custom class name" do
          get "/embed/comments",
              params: {
                embed_url: embed_url,
              },
              headers: {
                "REFERER" => "https://example.com/some-other-path",
              }

          expect(response.body).to match('class="example"')
        end

        it "contains custom class name from params" do
          get "/embed/comments",
              params: {
                embed_url: embed_url,
                class_name: "param-class-name",
              },
              headers: {
                "REFERER" => "https://example.com/some-other-path",
              }

          expect(response.body).to match('class="param-class-name"')
        end
      end

      context "with CSP frame-ancestors enabled" do
        before { SiteSetting.content_security_policy_frame_ancestors = true }

        it "includes all the hosts" do
          get "/embed/comments",
              params: {
                embed_url: embed_url,
              },
              headers: {
                "REFERER" => "http://eviltrout.com/wat/1-2-3.html",
              }

          expect(response.headers["Content-Security-Policy"]).to match(
            %r{frame-ancestors.*https://discourse\.org},
          )
          expect(response.headers["Content-Security-Policy"]).to match(
            %r{frame-ancestors.*https://example\.com},
          )
        end
      end
    end
  end
end
