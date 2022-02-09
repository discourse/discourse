# frozen_string_literal: true

require 'rails_helper'

describe SearchIndexer do
  let(:post_id) { 99 }

  before do
    SearchIndexer.enable
  end

  after do
    SearchIndexer.disable
  end

  def scrub(html, strip_diacritics: false)
    SearchIndexer.scrub_html_for_search(html, strip_diacritics: strip_diacritics)
  end

  it 'correctly indexes chinese' do
    SiteSetting.default_locale = 'zh_CN'
    data = "你好世界"

    SearchIndexer.update_posts_index(
      post_id: post_id,
      topic_title: "",
      category_name: "",
      topic_tags: "",
      cooked: data,
      private_message: false
    )

    post_search_data = PostSearchData.find_by(post_id: post_id)

    expect(post_search_data.raw_data).to eq("你好 世界")
    expect(post_search_data.search_data).to eq("'世界':2 '你好':1")
  end

  it 'extract youtube title' do
    html = "<div class=\"lazyYT\" data-youtube-id=\"lmFgeFh2nlw\" data-youtube-title=\"Metallica Mixer Explains Missing Bass on 'And Justice for All' [Exclusive]\" data-width=\"480\" data-height=\"270\" data-parameters=\"feature=oembed&amp;wmode=opaque\"></div>"
    scrubbed = scrub(html)
    expect(scrubbed).to eq("Metallica Mixer Explains Missing Bass on 'And Justice for All' [Exclusive]")
  end

  it 'extract a link' do
    html = "<a href='http://meta.discourse.org/'>link</a>"
    scrubbed = scrub(html)
    expect(scrubbed).to eq("http://meta.discourse.org/ link")
  end

  it 'extracts @username from mentions' do
    html = '<p><a class="mention" href="/u/%E7%8B%AE%E5%AD%90">@狮子</a> <a class="mention" href="/u/foo">@foo</a></p>'
    scrubbed = scrub(html)
    expect(scrubbed).to eq('@狮子 @foo')
  end

  it 'extracts @groupname from group mentions' do
    html = '<p><a class="mention-group" href="/groups/%D0%B0%D0%B2%D1%82%D0%BE%D0%BC%D0%BE%D0%B1%D0%B8%D0%BB%D0%B8%D1%81%D1%82">@автомобилист</a></p>'
    scrubbed = scrub(html)
    expect(scrubbed).to eq('@автомобилист')
  end

  it 'extracts emoji name from emoji image' do
    emoji = Emoji["wink"]
    html = %Q|<img src=\"#{URI.join(Discourse.base_url_no_prefix, emoji.url)}\" title=\":wink:\" class=\"emoji only-emoji\" alt=\":wink:\" loading=\"lazy\" width=\"20\" height=\"20\">|
    scrubbed = scrub(html)

    expect(scrubbed).to eq(':wink:')
  end

  it 'uses ignore_accent setting to strip diacritics' do
    html = "<p>HELLO Hétérogénéité Здравствуйте هتاف للترحيب 你好</p>"

    SiteSetting.search_ignore_accents = true
    scrubbed = SearchIndexer.scrub_html_for_search(html)
    expect(scrubbed).to eq("HELLO Heterogeneite Здравствуите هتاف للترحيب 你好")

    SiteSetting.search_ignore_accents = false
    scrubbed = SearchIndexer.scrub_html_for_search(html)
    expect(scrubbed).to eq("HELLO Hétérogénéité Здравствуйте هتاف للترحيب 你好")
  end

  it "doesn't index local files" do
    html = <<~HTML
      <p><img src="https://www.discourse.org/logo.png" alt="Discourse"></p>
      <p><img src="#{Discourse.base_url_no_prefix}/uploads/episodeinteractive/original/3X/0/f/0f40b818356bdc1d80acfa905034e95cfd112a3a.png" alt="51%20PM" width="289" height="398"></p>
      <div class="lightbox-wrapper">
        <a class="lightbox" href="#{Discourse.base_url_no_prefix}/uploads/episodeinteractive/original/3X/1/6/16790095df3baf318fb2eb1d7e5d7860dc45d48b.jpg" data-download-href="#{Discourse.base_url_no_prefix}/uploads/episodeinteractive/16790095df3baf318fb2eb1d7e5d7860dc45d48b" title="Untitled design (21).jpg" rel="nofollow noopener">
          <img src="#{Discourse.base_url_no_prefix}/uploads/episodeinteractive/optimized/3X/1/6/16790095df3baf318fb2eb1d7e5d7860dc45d48b_1_563x500.jpg" alt="Untitled%20design%20(21)" width="563" height="500">
          <div class="meta">
            <svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg>
            <span class="filename">Untitled design (21).jpg</span>
            <span class="informations">1280x1136 472 KB</span>
            <svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg>
          </div>
        </a>
      </div>
    HTML

    scrubbed = scrub(html)

    expect(scrubbed).to eq("Discourse 51%20PM Untitled%20design%20(21)")
  end

  it 'correctly indexes a post according to version' do
    # Preparing so that they can be indexed to right version
    SearchIndexer.update_posts_index(
      post_id: post_id,
      topic_title: "dummy",
      category_name: "",
      topic_tags: nil,
      cooked: nil,
      private_message: false
    )

    PostSearchData.find_by(post_id: post_id).update!(version: -1)

    data = "<a>This</a> is a test"

    SearchIndexer.update_posts_index(
      post_id: post_id,
      topic_title: "",
      category_name: "",
      topic_tags: nil,
      cooked: data,
      private_message: false
    )

    raw_data, locale, version = PostSearchData.where(post_id: post_id).pluck(:raw_data, :locale, :version)[0]
    expect(raw_data).to eq("This is a test")
    expect(locale).to eq(SiteSetting.default_locale)
    expect(version).to eq(SearchIndexer::POST_INDEX_VERSION)
  end

  describe '.index' do
    let(:topic) { Fabricate(:topic, title: "this is a title that I am testing") }
    let(:post) { Fabricate(:post, topic: topic) }

    it 'should index posts correctly' do
      expect { post }.to change { PostSearchData.count }.by(1)

      expect { post.update!(raw: "this is new content") }
        .to change { post.reload.post_search_data.search_data }

      expect { post.update!(topic_id: Fabricate(:topic).id) }
        .to change { post.reload.post_search_data.search_data }
    end

    it 'should work with invalid HTML' do
      post.update!(cooked: "<FD>" * Nokogiri::Gumbo::DEFAULT_MAX_TREE_DEPTH)

      SearchIndexer.update_posts_index(
        post_id: post.id,
        topic_title: post.topic.title,
        category_name: post.topic.category&.name,
        topic_tags: post.topic.tags.map(&:name).join(' '),
        cooked: post.cooked,
        private_message: post.topic.private_message?
      )
    end

    it 'should not index posts with empty raw' do
      expect do
        post = Fabricate.build(:post, raw: "", post_type: Post.types[:small_action])
        post.save!(validate: false)
      end.to_not change { PostSearchData.count }
    end

    it "should not tokenize urls and duplicate title and href in <a>" do
      post.update!(raw: <<~RAW)
      https://meta.discourse.org/some.png
      RAW

      post.rebake!
      post.reload

      expect(post.post_search_data.raw_data).to eq(
        "https://meta.discourse.org/some.png"
      )

      expect(post.post_search_data.search_data).to eq(
        "'/some.png':12 'discourse.org':11 'meta.discourse.org':11 'meta.discourse.org/some.png':10 'org':11 'test':8A 'titl':4A 'uncategor':9B"
      )
    end

    it 'should not tokenize versions' do
      post.update!(raw: '123.223')

      expect(post.post_search_data.search_data).to eq(
        "'123.223':10 'test':8A 'titl':4A 'uncategor':9B"
      )

      post.update!(raw: '15.2.231.423')
      post.reload

      expect(post.post_search_data.search_data).to eq(
        "'15.2.231.423':10 'test':8A 'titl':4A 'uncategor':9B"
      )
    end

    it 'should tokenize host of a URL and removes query string' do
      category = Fabricate(:category, name: 'awesome category')
      topic = Fabricate(:topic, category: category, title: 'this is a test topic')

      post = Fabricate(:post, topic: topic, raw: <<~RAW)
      a https://abc.com?bob=1, http://efg.com.au?bill=1 b hij.net/xyz=1
      www.klm.net/?IGNORE=1 <a href="http://abc.de.nop.co.uk?IGNORE=1&ignore2=2">test</a>
      RAW

      post.rebake!
      post.reload
      topic = post.topic

      # Note, a random non URL string should be tokenized properly,
      # hence www.klm.net?IGNORE=1 it was inserted in autolinking.
      # We could consider amending the auto linker to add
      # more context to say "hey, this part of <a href>...</a> was a guess by autolinker.
      # A blanket treating of non-urls without this logic is risky.
      expect(post.post_search_data.raw_data).to eq(
        "a https://abc.com , http://efg.com.au b http://hij.net/xyz=1 hij.net/xyz=1 http://www.klm.net/ www.klm.net/?IGNORE=1 http://abc.de.nop.co.uk test"
      )

      expect(post.post_search_data.search_data).to eq(
        "'/?ignore=1':21 '/xyz=1':14,17 'abc.com':9 'abc.de.nop.co.uk':22 'au':10 'awesom':6B 'b':11 'categori':7B 'co.uk':22 'com':9 'com.au':10 'de.nop.co.uk':22 'efg.com.au':10 'hij.net':13,16 'hij.net/xyz=1':12,15 'klm.net':18,20 'net':13,16,18,20 'nop.co.uk':22 'test':4A,23 'topic':5A 'uk':22 'www.klm.net':18,20 'www.klm.net/?ignore=1':19"
      )
    end

    it 'should not include lightbox in search' do
      Jobs.run_immediately!
      SiteSetting.max_image_width = 1

      stub_request(:get, "https://meta.discourse.org/some.png")
        .to_return(status: 200, body: file_from_fixtures("logo.png").read)

      src = "https://meta.discourse.org/some.png"

      post = Fabricate(:post, raw: <<~RAW)
      Let me see how I can fix this image
      <img src="#{src}" title="GOT" alt="white walkers" width="2" height="2">
      RAW

      post.rebake!
      post.reload

      expect(post.cooked).not_to include(
        CookedPostProcessor::LIGHTBOX_WRAPPER_CSS_CLASS
      )

      expect(post.post_search_data.raw_data).to eq(
        "Let me see how I can fix this image white walkers GOT"
      )
    end

    it 'should strips audio and videos URLs from raw data' do
      SiteSetting.authorized_extensions = 'mp4'
      Fabricate(:video_upload)

      post.update!(raw: <<~RAW)
      link to an external page: https://google.com/?u=bar

      link to an audio file: https://somesite.com/audio.m4a

      link to a video file: https://somesite.com/content/somethingelse.MOV

      link to an invalid URL: http:error]
      RAW

      expect(post.post_search_data.raw_data).to eq(
        "link to an external page: https://google.com/ link to an audio file: #{I18n.t("search.audio")} link to a video file: #{I18n.t("search.video")} link to an invalid URL: http:error]"
      )

      expect(post.post_search_data.search_data).to eq(
        "'/audio.m4a':23 '/content/somethingelse.mov':31 'audio':19 'com':15,22,30 'error':38 'extern':13 'file':20,28 'google.com':15 'http':37 'invalid':35 'link':10,16,24,32 'page':14 'somesite.com':22,30 'somesite.com/audio.m4a':21 'somesite.com/content/somethingelse.mov':29 'test':8A 'titl':4A 'uncategor':9B 'url':36 'video':27"
      )
    end
  end

  describe '.queue_post_reindex' do
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic }

    it 'should reset the version of search data for all posts in the topic' do
      post2 = Fabricate(:post)

      SearchIndexer.queue_post_reindex(topic.id)

      expect(post.reload.post_search_data.version).to eq(
        SearchIndexer::REINDEX_VERSION
      )

      expect(post2.reload.post_search_data.version).to eq(
        SearchIndexer::POST_INDEX_VERSION
      )
    end
  end

  describe '.queue_users_reindex' do
    let!(:user) { Fabricate(:user) }
    let!(:user2) { Fabricate(:user) }

    it 'should reset the version of search data for all users' do
      SearchIndexer.index(user, force: true)
      SearchIndexer.index(user2, force: true)
      SearchIndexer.queue_users_reindex([user.id])

      expect(user.reload.user_search_data.version).to eq(
        SearchIndexer::REINDEX_VERSION
      )

      expect(user2.reload.user_search_data.version).to eq(
        SearchIndexer::USER_INDEX_VERSION
      )
    end
  end
end
