require 'rails_helper'

describe TopicLinkClick do

  it { is_expected.to belong_to :topic_link }
  it { is_expected.to belong_to :user }
  it { is_expected.to validate_presence_of :topic_link_id }

  def test_uri
    URI.parse('http://test.host')
  end

  context 'topic_links' do
    before do
      @topic = Fabricate(:topic)
      @post = Fabricate(:post_with_external_links, user: @topic.user, topic: @topic)
      TopicLink.extract_from(@post)
      @topic_link = @topic.topic_links.first
    end

    it 'has 0 clicks at first' do
      expect(@topic_link.clicks).to eq(0)
    end

    context 'create' do
      before do
        TopicLinkClick.create(topic_link: @topic_link, ip_address: '192.168.1.1')
      end

      it 'creates the forum topic link click' do
        expect(TopicLinkClick.count).to eq(1)

        @topic_link.reload
        expect(@topic_link.clicks).to eq(1)

        expect(TopicLinkClick.first.ip_address.to_s).to eq('192.168.1.1')
      end
    end

    context 'create_from' do


      it "works correctly" do

        # returns nil to prevent exploits
        click = TopicLinkClick.create_from(url: "http://url-that-doesnt-exist.com", post_id: @post.id, ip: '127.0.0.1')
        expect(click).to eq(nil)

        # redirects if whitelisted
        click = TopicLinkClick.create_from(url: "https://www.youtube.com/watch?v=jYd_5aggzd4", post_id: @post.id, ip: '127.0.0.1')
        expect(click).to eq("https://www.youtube.com/watch?v=jYd_5aggzd4")

        # does not change own link
        expect {
          TopicLinkClick.create_from(url: @topic_link.url, post_id: @post.id, ip: '127.0.0.0', user_id: @post.user_id)
        }.not_to change(TopicLinkClick, :count)

      end



      context 'with a valid url and post_id' do
        before do
          @url = TopicLinkClick.create_from(url: @topic_link.url, post_id: @post.id, ip: '127.0.0.1')
          @click = TopicLinkClick.last
        end

        it 'creates a click' do
          expect(@click).to be_present
          expect(@click.topic_link).to eq(@topic_link)
          expect(@url).to eq(@topic_link.url)

          # second click should not record
          expect { TopicLinkClick.create_from(url: @topic_link.url, post_id: @post.id, ip: '127.0.0.1') }.not_to change(TopicLinkClick, :count)
        end

      end

      context "relative urls" do
        let(:host) { URI.parse(Discourse.base_url).host }

        it 'returns the url' do
          url = TopicLinkClick.create_from(url: '/relative-url', post_id: @post.id, ip: '127.0.0.1')
          expect(url).to eq("/relative-url")
        end

        it 'finds a protocol relative urls with a host' do
          url = "//#{host}/relative-url"
          redirect = TopicLinkClick.create_from(url: url)
          expect(redirect).to eq(url)
        end

        it "returns the url if it's on our host" do
          url = "http://#{host}/relative-url"
          redirect = TopicLinkClick.create_from(url: url)
          expect(redirect).to eq(url)
        end

        context "cdn links" do

          before do
            Rails.configuration.action_controller.asset_host = "https://cdn.discourse.org/stuff"
          end

          after do
            Rails.configuration.action_controller.asset_host = nil
          end

          it "correctly handles cdn links" do

            url = TopicLinkClick.create_from(
              url: 'https://cdn.discourse.org/stuff/my_link',
              topic_id: @topic.id,
              ip: '127.0.0.3')

            expect(url).to eq('https://cdn.discourse.org/stuff/my_link')

            # cdn exploit
            url = TopicLinkClick.create_from(
              url: 'https://cdn.discourse.org/bad/my_link',
              topic_id: @topic.id,
              ip: '127.0.0.3')

            expect(url).to eq(nil)

            # cdn better link track
            path = "/uploads/site/29/5b585f848d8761d5.xls"

            post = Fabricate(:post, topic: @topic, raw: "[test](#{path})")
            TopicLink.extract_from(post)

            url = TopicLinkClick.create_from(
              url: "https://cdn.discourse.org/stuff#{path}",
              topic_id: post.topic_id,
              post_id: post.id,
              ip: '127.0.0.3')

            expect(url).to eq("https://cdn.discourse.org/stuff#{path}")

            click = TopicLinkClick.order('id desc').first

            expect(click.topic_link_id).to eq(TopicLink.order('id desc').first.id)
          end

        end

      end

      context 'with a HTTPS version of the same URL' do
        before do
          @url = TopicLinkClick.create_from(url: 'https://twitter.com', topic_id: @topic.id, ip: '127.0.0.3')
          @click = TopicLinkClick.last
        end

        it 'creates a click' do
          expect(@click).to be_present
          expect(@click.topic_link).to eq(@topic_link)
          expect(@url).to eq('https://twitter.com')
        end
      end

      context 'with a valid url and topic_id' do
        before do
          @url = TopicLinkClick.create_from(url: @topic_link.url, topic_id: @topic.id, ip: '127.0.0.3')
          @click = TopicLinkClick.last
        end

        it 'creates a click' do
          expect(@click).to be_present
          expect(@click.topic_link).to eq(@topic_link)
          expect(@url).to eq(@topic_link.url)
        end

      end

    end

  end

end
