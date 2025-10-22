# frozen_string_literal: true

RSpec.describe TopicLinkClick do
  it { is_expected.to belong_to :topic_link }
  it { is_expected.to belong_to :user }
  it { is_expected.to validate_presence_of :topic_link_id }

  def test_uri
    URI.parse("http://test.host")
  end

  describe "topic_links" do
    fab!(:topic) { Fabricate(:topic, user: Fabricate(:user, refresh_auto_groups: true)) }
    fab!(:post) { Fabricate(:post_with_external_links, user: topic.user, topic:) }

    let(:topic_link) { topic.topic_links.first }

    before { TopicLink.extract_from(post) }

    it "has 0 clicks at first" do
      expect(topic_link.clicks).to eq(0)
    end

    describe ".create" do
      before { described_class.create(topic_link:, ip_address: "192.168.1.1") }

      it "creates the forum topic link click" do
        expect(described_class.count).to eq(1)

        topic_link.reload
        expect(topic_link.clicks).to eq(1)

        expect(described_class.first.ip_address.to_s).to eq("192.168.1.1")
      end
    end

    describe ".create_from" do
      it "works correctly" do
        # returns nil to prevent exploits
        click =
          described_class.create_from(
            url: "http://url-that-doesnt-exist.com",
            post_id: post.id,
            ip: "127.0.0.1",
          )
        expect(click).to eq(nil)

        # redirects if allowlisted
        click =
          described_class.create_from(
            url: "https://www.youtube.com/watch?v=jYd_5aggzd4",
            post_id: post.id,
            ip: "127.0.0.1",
          )
        expect(click).to eq("https://www.youtube.com/watch?v=jYd_5aggzd4")

        # does not change own link
        expect {
          described_class.create_from(
            url: topic_link.url,
            post_id: post.id,
            ip: "127.0.0.0",
            user_id: post.user_id,
          )
        }.not_to change(described_class, :count)

        # can handle double # in a url
        # NOTE: this is not compliant but exists in the wild
        click =
          described_class.create_from(
            url: "http://discourse.org#a#b",
            post_id: post.id,
            ip: "127.0.0.1",
          )
        expect(click).to eq("http://discourse.org#a#b")
      end

      context "with a valid url and post_id" do
        let!(:url) do
          described_class.create_from(url: topic_link.url, post_id: post.id, ip: "127.0.0.1")
        end
        let(:click) { described_class.last }

        it "creates a click" do
          expect(click).to be_present
          expect(click.topic_link).to eq(topic_link)
          expect(url).to eq(topic_link.url)

          # second click should not record
          expect {
            described_class.create_from(url: topic_link.url, post_id: post.id, ip: "127.0.0.1")
          }.not_to change(described_class, :count)
        end
      end

      context "while logged in" do
        fab!(:other_user, :user)

        let!(:url) do
          described_class.create_from(
            url: topic_link.url,
            post_id: post.id,
            ip: "127.0.0.1",
            user_id: other_user.id,
          )
        end
        let(:click) { described_class.last }

        it "creates a click without an IP" do
          expect(click).to be_present
          expect(click.topic_link).to eq(topic_link)
          expect(click.user_id).to eq(other_user.id)
          expect(click.ip_address).to eq(nil)
        end
      end

      context "with relative urls" do
        let(:host) { URI.parse(Discourse.base_url).host }

        it "returns the url" do
          url = described_class.create_from(url: "/relative-url", post_id: post.id, ip: "127.0.0.1")
          expect(url).to eq("/relative-url")
        end

        it "finds a protocol relative urls with a host" do
          url = "//#{host}/relative-url"
          redirect = described_class.create_from(url: url)
          expect(redirect).to eq(url)
        end

        it "returns the url if it's on our host" do
          url = "http://#{host}/relative-url"
          redirect = described_class.create_from(url: url)
          expect(redirect).to eq(url)
        end

        context "with cdn links" do
          before do
            Rails.configuration.action_controller.asset_host = "https://cdn.discourse.org/stuff"
          end

          after { Rails.configuration.action_controller.asset_host = nil }

          it "correctly handles cdn links" do
            url =
              described_class.create_from(
                url: "https://cdn.discourse.org/stuff/my_link",
                topic_id: topic.id,
                ip: "127.0.0.3",
              )

            expect(url).to eq("https://cdn.discourse.org/stuff/my_link")

            # cdn exploit
            url =
              described_class.create_from(
                url: "https://cdn.discourse.org/bad/my_link",
                topic_id: topic.id,
                ip: "127.0.0.3",
              )

            expect(url).to eq(nil)

            # cdn better link track
            path = "/uploads/site/29/5b585f848d8761d5.xls"

            post = Fabricate(:post, topic:, raw: "[test](#{path})")
            TopicLink.extract_from(post)

            url =
              described_class.create_from(
                url: "https://cdn.discourse.org/stuff#{path}",
                topic_id: post.topic_id,
                post_id: post.id,
                ip: "127.0.0.3",
              )

            expect(url).to eq("https://cdn.discourse.org/stuff#{path}")

            click = described_class.order("id desc").first

            expect(click.topic_link_id).to eq(TopicLink.order("id desc").first.id)
          end
        end

        context "with s3 cdns" do
          it "works with s3 urls" do
            setup_s3
            SiteSetting.s3_cdn_url = "https://discourse-s3-cdn.global.ssl.fastly.net"

            post =
              Fabricate(:post, topic:, raw: "[test](//test.localhost/uploads/default/my-test-link)")
            TopicLink.extract_from(post)

            url =
              described_class.create_from(
                url: "https://discourse-s3-cdn.global.ssl.fastly.net/my-test-link",
                topic_id: topic.id,
                ip: "127.0.0.3",
              )

            expect(url).to be_present
          end
        end
      end

      context "with a HTTPS version of the same URL" do
        let!(:url) do
          described_class.create_from(
            url: "https://twitter.com",
            topic_id: topic.id,
            ip: "127.0.0.3",
          )
        end
        let(:click) { described_class.last }

        it "creates a click" do
          expect(click).to be_present
          expect(click.topic_link).to eq(topic_link)
          expect(url).to eq("https://twitter.com")
        end
      end

      context "with a google analytics tracking code" do
        let!(:url) do
          described_class.create_from(
            url: "http://twitter.com?_ga=1.16846778.221554446.1071987018",
            topic_id: topic.id,
            ip: "127.0.0.3",
          )
        end
        let(:click) { described_class.last }

        it "creates a click" do
          expect(click).to be_present
          expect(click.topic_link).to eq(topic_link)
          expect(url).to eq("http://twitter.com?_ga=1.16846778.221554446.1071987018")
        end
      end

      context "with a query param and google analytics" do
        let(:topic) { Fabricate(:topic, user: Fabricate(:user, refresh_auto_groups: true)) }
        let!(:post) do
          Fabricate(
            :post,
            topic:,
            user: topic.user,
            raw: "Here's a link to twitter: http://twitter.com?ref=forum",
          )
        end
        let(:topic_link) { topic.topic_links.first }

        before { TopicLink.extract_from(post) }

        it "creates a click" do
          url =
            described_class.create_from(
              url: "http://twitter.com?ref=forum&_ga=1.16846778.221554446.1071987018",
              topic_id: topic.id,
              post_id: post.id,
              ip: "127.0.0.3",
            )
          click = described_class.last
          expect(click).to be_present
          expect(click.topic_link).to eq(topic_link)
          expect(url).to eq("http://twitter.com?ref=forum&_ga=1.16846778.221554446.1071987018")
        end
      end

      context "with same base URL with different query" do
        it "are handled differently" do
          post = Fabricate(:post, raw: <<~RAW)
            no query param: http://example.com/a
            with query param: http://example.com/a?b=c
            with two query params: http://example.com/a?b=c&d=e
          RAW

          TopicLink.extract_from(post)

          described_class.create_from(
            url: "http://example.com/a",
            post_id: post.id,
            ip: "127.0.0.1",
            user: Fabricate(:user),
          )
          described_class.create_from(
            url: "http://example.com/a?b=c",
            post_id: post.id,
            ip: "127.0.0.2",
            user: Fabricate(:user),
          )
          described_class.create_from(
            url: "http://example.com/a?b=c&d=e",
            post_id: post.id,
            ip: "127.0.0.3",
            user: Fabricate(:user),
          )
          described_class.create_from(
            url: "http://example.com/a?b=c",
            post_id: post.id,
            ip: "127.0.0.4",
            user: Fabricate(:user),
          )

          expect(
            TopicLink.where("url LIKE '%example.com%'").pluck(:url, :clicks),
          ).to contain_exactly(
            ["http://example.com/a", 1],
            ["http://example.com/a?b=c", 2],
            ["http://example.com/a?b=c&d=e", 1],
          )
        end
      end

      context "with a google analytics tracking code and a hash" do
        let!(:url) do
          described_class.create_from(
            url: "http://discourse.org?_ga=1.16846778.221554446.1071987018#faq",
            topic_id: topic.id,
            ip: "127.0.0.3",
          )
        end
        let(:click) { described_class.last }

        it "creates a click" do
          expect(click).to be_present
          expect(url).to eq("http://discourse.org?_ga=1.16846778.221554446.1071987018#faq")
        end
      end

      context "with a valid url and topic_id" do
        let!(:url) do
          described_class.create_from(url: topic_link.url, topic_id: topic.id, ip: "127.0.0.3")
        end
        let(:click) { described_class.last }

        it "creates a click" do
          expect(click).to be_present
          expect(click.topic_link).to eq(topic_link)
          expect(url).to eq(topic_link.url)
        end
      end
    end
  end
end
