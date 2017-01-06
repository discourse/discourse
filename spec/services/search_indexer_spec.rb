require 'rails_helper'

describe SearchIndexer do

  it 'correctly indexes chinese' do
    SiteSetting.default_locale = 'zh_CN'
    data = "你好世界"
    expect(data.split(" ").length).to eq(1)

    SearchIndexer.update_posts_index(99, "你好世界", "", nil)

    raw_data = PostSearchData.where(post_id: 99).pluck(:raw_data)[0]
    expect(raw_data.split(' ').length).to eq(2)
  end

  it 'correctly indexes a post' do
    data = "<a>This</a> is a test"

    SearchIndexer.update_posts_index(99, data, "", nil)

    raw_data, locale = PostSearchData.where(post_id: 99).pluck(:raw_data, :locale)[0]
    expect(raw_data).to eq("This is a test")
    expect(locale).to eq("en")

    SearchIndexer.update_posts_index(99, "tester", "", nil)

    raw_data = PostSearchData.where(post_id: 99).pluck(:raw_data)[0]
    expect(raw_data).to eq("tester")
  end
end
