# frozen_string_literal: true

require 'rails_helper'

describe TopicLink do

  it { is_expected.to validate_presence_of :url }

  def test_uri
    URI.parse(Discourse.base_url)
  end

  fab!(:topic) do
    Fabricate(:topic, title: 'unique topic name')
  end

  fab!(:user) do
    topic.user
  end

  fab!(:post) { Fabricate(:post) }

  it "can't link to the same topic" do
    ftl = TopicLink.new(url: "/t/#{topic.id}",
                        topic_id: topic.id,
                        link_topic_id: topic.id)
    expect(ftl.valid?).to eq(false)
  end

  describe 'external links' do
    fab!(:post2) do
      Fabricate(:post, raw: <<~RAW, user: user, topic: topic)
        http://a.com/
        https://b.com/b
        http://#{'a' * 200}.com/invalid
        //b.com/#{'a' * 500}
      RAW
    end

    before do
      TopicLink.extract_from(post2)
    end

    it 'works' do
      expect(topic.topic_links.pluck(:url)).to contain_exactly(
        "http://a.com/",
        "https://b.com/b",
        "//b.com/#{'a' * 500}"[0...TopicLink.max_url_length]
      )
    end

    it "doesn't reset them when rebaking" do
      old_ids = topic.topic_links.pluck(:id)

      TopicLink.extract_from(post2)

      new_ids = topic.topic_links.pluck(:id)

      expect(new_ids).to contain_exactly(*old_ids)
    end

  end

  describe 'internal links' do

    it "extracts onebox" do
      other_topic = Fabricate(:topic, user: user)
      other_topic.posts.create(user: user, raw: "some content for the first post")
      other_post = other_topic.posts.create(user: user, raw: "some content for the second post")

      url = "http://#{test_uri.host}/t/#{other_topic.slug}/#{other_topic.id}/#{other_post.post_number}"
      invalid_url = "http://#{test_uri.host}/t/#{other_topic.slug}/9999999999999999999999999999999"

      topic.posts.create(user: user, raw: 'initial post')
      post = topic.posts.create(user: user, raw: "Link to another topic:\n\n#{url}\n\n#{invalid_url}")
      post.reload

      TopicLink.extract_from(post)

      link = topic.topic_links.first
      # should have a link
      expect(link).to be_present
      # should be the canonical URL
      expect(link.url).to eq(url)
    end

    context 'topic link' do

      fab!(:other_topic) do
        Fabricate(:topic, user: user)
      end

      let(:post) do
        other_topic.posts.create(user: user, raw: "some content")
      end

      it 'works' do

        # ensure other_topic has a post
        post

        url = "http://#{test_uri.host}/t/#{other_topic.slug}/#{other_topic.id}"

        topic.posts.create(user: user, raw: 'initial post')
        linked_post = topic.posts.create(user: user, raw: "Link to another topic: #{url}")

        # this is subtle, but we had a bug were second time
        # TopicLink.extract_from was called a reflection was nuked
        2.times do
          topic.reload
          TopicLink.extract_from(linked_post)

          link = topic.topic_links.first
          expect(link).to be_present
          expect(link).to be_internal
          expect(link.url).to eq(url)
          expect(link.domain).to eq(test_uri.host)
          link.link_topic_id == other_topic.id
          expect(link).not_to be_reflection

          reflection = other_topic.topic_links.first

          expect(reflection).to be_present
          expect(reflection).to be_reflection
          expect(reflection.post_id).to be_present
          expect(reflection.domain).to eq(test_uri.host)
          expect(reflection.url).to eq("http://#{test_uri.host}/t/unique-topic-name/#{topic.id}/#{linked_post.post_number}")
          expect(reflection.link_topic_id).to eq(topic.id)
          expect(reflection.link_post_id).to eq(linked_post.id)

          expect(reflection.user_id).to eq(link.user_id)
        end

        PostOwnerChanger.new(
          post_ids: [linked_post.id],
          topic_id: topic.id,
          acting_user: user,
          new_owner: Fabricate(:user)
        ).change_owner!

        TopicLink.extract_from(linked_post)
        expect(topic.topic_links.first.url).to eq(url)

        linked_post.revise(post.user, raw: "no more linkies https://eviltrout.com")
        expect(other_topic.reload.topic_links.where(link_post_id: linked_post.id)).to be_blank
      end

      it 'works without id' do
        post
        url = "http://#{test_uri.host}/t/#{other_topic.slug}"
        topic.posts.create(user: user, raw: 'initial post')
        linked_post = topic.posts.create(user: user, raw: "Link to another topic: #{url}")

        TopicLink.extract_from(linked_post)
        link = topic.topic_links.first

        reflection = other_topic.topic_links.first

        expect(reflection).to be_present
        expect(reflection).to be_reflection
        expect(reflection.post_id).to be_present
        expect(reflection.domain).to eq(test_uri.host)
        expect(reflection.url).to eq("http://#{test_uri.host}/t/unique-topic-name/#{topic.id}/#{linked_post.post_number}")
        expect(reflection.link_topic_id).to eq(topic.id)
        expect(reflection.link_post_id).to eq(linked_post.id)
        expect(reflection.user_id).to eq(link.user_id)
      end
    end

    context "link to a user on discourse" do
      let(:post) { topic.posts.create(user: user, raw: "<a href='/u/#{user.username_lower}'>user</a>") }
      before do
        TopicLink.extract_from(post)
      end

      it 'does not extract a link' do
        expect(topic.topic_links).to be_blank
      end
    end

    context "link to a discourse resource like a FAQ" do
      let(:post) { topic.posts.create(user: user, raw: "<a href='/faq'>faq link here</a>") }
      before do
        TopicLink.extract_from(post)
      end

      it 'does not extract a link' do
        expect(topic.topic_links).to be_present
      end
    end

    context "mention links" do
      let(:post) { topic.posts.create(user: user, raw: "Hey #{user.username_lower}") }

      before do
        TopicLink.extract_from(post)
      end

      it 'does not extract a link' do
        expect(topic.topic_links).to be_blank
      end
    end

    context "email address" do
      it "does not extract a link" do
        post = topic.posts.create(user: user, raw: "Valid email: foo@bar.com\n\nInvalid email: rfc822;name@domain.com")
        TopicLink.extract_from(post)
        expect(topic.topic_links).to be_blank
      end
    end

    context "mail link" do
      let(:post) { topic.posts.create(user: user, raw: "[email]bar@example.com[/email]") }

      it 'does not extract a link' do
        TopicLink.extract_from(post)
        expect(topic.topic_links).to be_blank
      end
    end

    context "quote links" do
      it "sets quote correctly" do
        linked_post = topic.posts.create(user: user, raw: "my test post")
        quoting_post = Fabricate(:post, raw: "[quote=\"#{user.username}, post: #{linked_post.post_number}, topic: #{topic.id}\"]\nquote\n[/quote]")

        TopicLink.extract_from(quoting_post)
        link = quoting_post.topic.topic_links.first

        expect(link.link_post_id).to eq(linked_post.id)
        expect(link.quote).to eq(true)
      end
    end

    context "link to a local attachments" do
      let(:post) { topic.posts.create(user: user, raw: '<a class="attachment" href="/uploads/default/208/87bb3d8428eb4783.rb?foo=bar">ruby.rb</a>') }

      it "extracts the link" do
        TopicLink.extract_from(post)
        link = topic.topic_links.first
        # extracted the link
        expect(link).to be_present
        # is set to internal
        expect(link).to be_internal
        # has the correct url
        expect(link.url).to eq("/uploads/default/208/87bb3d8428eb4783.rb?foo=bar")
        # should not be the reflection
        expect(link).not_to be_reflection
        # should have file extension
        expect(link.extension).to eq('rb')
      end

    end

    context "link to an attachments uploaded on S3" do
      let(:post) { topic.posts.create(user: user, raw: '<a class="attachment" href="//s3.amazonaws.com/bucket/2104a0211c9ce41ed67989a1ed62e9a394c1fbd1446.rb">ruby.rb</a>') }

      it "extracts the link" do
        TopicLink.extract_from(post)
        link = topic.topic_links.first
        # extracted the link
        expect(link).to be_present
        # is not internal
        expect(link).not_to be_internal
        # has the correct url
        expect(link.url).to eq("//s3.amazonaws.com/bucket/2104a0211c9ce41ed67989a1ed62e9a394c1fbd1446.rb")
        # should not be the reflection
        expect(link).not_to be_reflection
        # should have file extension
        expect(link.extension).to eq('rb')
      end

    end
  end

  describe 'internal link from pm' do
    it 'works' do
      pm = Fabricate(:topic, user: user, category_id: nil, archetype: 'private_message')
      pm.posts.create(user: user, raw: "some content")

      url = "http://#{test_uri.host}/t/topic-slug/#{topic.id}"

      pm.posts.create(user: user, raw: 'initial post')
      linked_post = pm.posts.create(user: user, raw: "Link to another topic: #{url}")

      TopicLink.extract_from(linked_post)

      expect(topic.topic_links.first).to eq(nil)
      expect(pm.topic_links.first).not_to eq(nil)
    end

  end

  describe 'internal link from unlisted topic' do
    it 'works' do
      unlisted_topic = Fabricate(:topic, user: user, visible: false)
      url = "http://#{test_uri.host}/t/topic-slug/#{topic.id}"

      unlisted_topic.posts.create(user: user, raw: 'initial post')
      linked_post = unlisted_topic.posts.create(user: user, raw: "Link to another topic: #{url}")

      TopicLink.extract_from(linked_post)

      expect(topic.topic_links.first).to eq(nil)
      expect(unlisted_topic.topic_links.first).not_to eq(nil)
    end
  end

  describe 'internal link with non-standard port' do
    it 'includes the non standard port if present' do
      other_topic = Fabricate(:topic, user: user)
      SiteSetting.port = 5678
      alternate_uri = URI.parse(Discourse.base_url)

      url = "http://#{alternate_uri.host}:5678/t/topic-slug/#{other_topic.id}"
      post = topic.posts.create(user: user, raw: "Link to another topic: #{url}")
      TopicLink.extract_from(post)
      reflection = other_topic.topic_links.first

      expect(reflection.url).to eq("http://#{alternate_uri.host}:5678/t/unique-topic-name/#{topic.id}")
    end
  end

  describe 'query methods' do
    it 'returns blank without posts' do
      expect(TopicLink.counts_for(Guardian.new, nil, nil)).to be_blank
    end

    context 'with data' do

      let(:post) do
        topic = Fabricate(:topic)
        Fabricate(:post_with_external_links, user: topic.user, topic: topic)
      end

      let(:counts_for) do
        TopicLink.counts_for(Guardian.new, post.topic, [post])
      end

      it 'creates a valid topic lookup' do
        TopicLink.extract_from(post)

        lookup = TopicLink.duplicate_lookup(post.topic)
        expect(lookup).to be_present
        expect(lookup['google.com']).to be_present

        ch = lookup['www.codinghorror.com/blog']
        expect(ch).to be_present
        expect(ch[:domain]).to eq('www.codinghorror.com')
        expect(ch[:username]).to eq(post.username)
        expect(ch[:posted_at]).to be_present
        expect(ch[:post_number]).to be_present
      end

      it 'has the correct results' do
        TopicLink.extract_from(post)
        topic_link_first = post.topic.topic_links.first
        TopicLinkClick.create!(topic_link: topic_link_first, ip_address: '192.168.1.1')
        TopicLinkClick.create!(topic_link: topic_link_first, ip_address: '192.168.1.2')
        topic_link_second = post.topic.topic_links.second
        TopicLinkClick.create!(topic_link: topic_link_second, ip_address: '192.168.1.1')

        expect(counts_for[post.id]).to be_present
        expect(counts_for[post.id].first[:clicks]).to eq(2)
        expect(counts_for[post.id].second[:clicks]).to eq(1)

        array = TopicLink.topic_map(Guardian.new, post.topic_id)
        expect(array.length).to eq(2)
        expect(array[0].clicks).to eq(2)
        expect(array[1].clicks).to eq(1)
      end

      it 'secures internal links correctly' do
        category = Fabricate(:category)
        secret_topic = Fabricate(:topic, category: category)

        url = "http://#{test_uri.host}/t/topic-slug/#{secret_topic.id}"
        post = Fabricate(:post, raw: "hello test topic #{url}")
        TopicLink.extract_from(post)
        TopicLinkClick.create!(topic_link: post.topic.topic_links.first, ip_address: '192.168.1.1')

        expect(TopicLink.topic_map(Guardian.new, post.topic_id).count).to eq(1)
        expect(TopicLink.counts_for(Guardian.new, post.topic, [post]).length).to eq(1)

        category.set_permissions(staff: :full)
        category.save

        admin = Fabricate(:admin)

        expect(TopicLink.topic_map(Guardian.new, post.topic_id).count).to eq(0)
        expect(TopicLink.topic_map(Guardian.new(admin), post.topic_id).count).to eq(1)

        expect(TopicLink.counts_for(Guardian.new, post.topic, [post]).length).to eq(0)
        expect(TopicLink.counts_for(Guardian.new(admin), post.topic, [post]).length).to eq(1)
      end

      it 'does not include links from whisper' do
        url = "https://blog.codinghorror.com/hacker-hack-thyself/"
        post = Fabricate(:post, raw: "whisper post... #{url}", post_type: Post.types[:whisper])
        TopicLink.extract_from(post)

        expect(TopicLink.topic_map(Guardian.new, post.topic_id).count).to eq(0)
      end
    end

    describe ".duplicate_lookup" do
      fab!(:user) { Fabricate(:user, username: "junkrat") }

      let(:post_with_internal_link) do
        Fabricate(:post, user: user, raw: "Check out this topic #{post.topic.url}/122131")
      end

      it "should return the right response" do
        TopicLink.extract_from(post_with_internal_link)

        result = TopicLink.duplicate_lookup(post_with_internal_link.topic)
        expect(result.count).to eq(1)

        lookup = result["test.localhost/t/#{post.topic.slug}/#{post.topic.id}/122131"]

        expect(lookup[:domain]).to eq("test.localhost")
        expect(lookup[:username]).to eq("junkrat")
        expect(lookup[:posted_at].to_s).to eq(post_with_internal_link.created_at.to_s)
        expect(lookup[:post_number]).to eq(1)

        result = TopicLink.duplicate_lookup(post.topic)
        expect(result).to eq({})
      end
    end

    it "works with invalid link target" do
      post = Fabricate(:post, raw: '<a href="http:geturl">http:geturl</a>', user: user, topic: topic, cook_method: Post.cook_methods[:raw_html])
      expect { TopicLink.extract_from(post) }.to_not raise_error
    end
  end

end
