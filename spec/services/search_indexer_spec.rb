require 'rails_helper'

describe SearchIndexer do
  let(:post_id) { 99 }
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

    scrubbed = SearchIndexer::HtmlScrubber.scrub(html)

    expect(scrubbed).to eq(" Metallica Mixer Explains Missing Bass on 'And Justice for All' [Exclusive] ")
  end

  it 'correctly indexes a post according to version' do
    # Preparing so that they can be indexed to right version
    SearchIndexer.update_posts_index(post_id, "dummy", "", nil, nil)
    PostSearchData.find_by(post_id: post_id).update_attributes!(version: -1)

    data = "<a>This</a> is a test"
    SearchIndexer.update_posts_index(post_id, "", "", nil, data)

    raw_data, locale, version = PostSearchData.where(post_id: post_id).pluck(:raw_data, :locale, :version)[0]
    expect(raw_data).to eq("This is a test")
    expect(locale).to eq("en")
    expect(version).to eq(Search::INDEX_VERSION)

    SearchIndexer.update_posts_index(post_id, "tester", "", nil, nil)

    raw_data = PostSearchData.where(post_id: post_id).pluck(:raw_data)[0]
    expect(raw_data).to eq("tester")
  end
end
