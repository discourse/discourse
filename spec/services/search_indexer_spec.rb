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

  it 'can correctly inject if http or https links exist' do

    val = "a https://cnn.com?bob=1, http://stuff.com.au?bill=1 b abc.net/xyz=1"
    result = SearchIndexer.inject_extra_terms(val)

    expected = "a https://cnn.com?bob=1, cnn com bob=1 http://stuff.com.au?bill=1 stuff com au bill=1 b abc.net/xyz=1 net xyz=1"

    expect(result).to eq(expected)
  end

  it 'correctly indexes chinese' do
    SiteSetting.default_locale = 'zh_CN'
    data = "你好世界"
    expect(data.split(" ").length).to eq(1)

    SearchIndexer.update_posts_index(post_id, "你好世界", "", "", nil)

    raw_data = PostSearchData.where(post_id: post_id).pluck(:raw_data)[0]
    expect(raw_data.split(' ').length).to eq(2)
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
    html = %Q|<img src="#{Discourse.base_url_no_prefix}/images/emoji/twitter/wink.png?v=9" title=":wink:" class="emoji" alt=":wink:">|
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
            <svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use xlink:href="#far-image"></use></svg>
            <span class="filename">Untitled design (21).jpg</span>
            <span class="informations">1280x1136 472 KB</span>
            <svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use xlink:href="#discourse-expand"></use></svg>
          </div>
        </a>
      </div>
    HTML

    scrubbed = scrub(html)

    expect(scrubbed).to eq("Discourse 51%20PM Untitled%20design%20(21)")
  end

  it 'correctly indexes a post according to version' do
    # Preparing so that they can be indexed to right version
    SearchIndexer.update_posts_index(post_id, "dummy", "", nil, nil)
    PostSearchData.find_by(post_id: post_id).update!(version: -1)

    data = "<a>This</a> is a test"
    SearchIndexer.update_posts_index(post_id, "", "", nil, data)

    raw_data, locale, version = PostSearchData.where(post_id: post_id).pluck(:raw_data, :locale, :version)[0]
    expect(raw_data).to eq("This is a test")
    expect(locale).to eq(SiteSetting.default_locale)
    expect(version).to eq(SearchIndexer::INDEX_VERSION)

    SearchIndexer.update_posts_index(post_id, "tester", "", nil, nil)

    raw_data = PostSearchData.where(post_id: post_id).pluck(:raw_data)[0]
    expect(raw_data).to eq("tester")
  end

  describe '.index' do
    let(:post) { Fabricate(:post) }

    it 'should index posts correctly' do
      expect { post }.to change { PostSearchData.count }.by(1)

      expect { post.update!(raw: "this is new content") }
        .to change { post.reload.post_search_data.raw_data }

      expect { post.update!(topic_id: Fabricate(:topic).id) }
        .to change { post.reload.post_search_data.raw_data }
    end

    it 'should not index posts with empty raw' do
      expect do
        post = Fabricate.build(:post, raw: "", post_type: Post.types[:small_action])
        post.save!(validate: false)
      end.to_not change { PostSearchData.count }
    end

    it "should not tokenize urls and duplicate title and href in <a>" do
      post = Fabricate(:post, raw: <<~RAW)
      https://meta.discourse.org/some.png
      RAW

      post.rebake!
      post.reload
      topic = post.topic

      expect(post.post_search_data.raw_data).to eq(
        "#{topic.title} #{topic.category.name} https://meta.discourse.org/some.png meta discourse org some png"
      )
    end

    it 'should not include lightbox in search' do
      Jobs.run_immediately!
      SiteSetting.crawl_images = true
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
      topic = post.topic

      expect(post.cooked).to include(
        CookedPostProcessor::LIGHTBOX_WRAPPER_CSS_CLASS
      )

      expect(post.post_search_data.raw_data).to eq(
        "#{topic.title} #{topic.category.name} Let me see how I can fix this image white walkers GOT"
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
        SearchIndexer::INDEX_VERSION
      )
    end
  end
end
