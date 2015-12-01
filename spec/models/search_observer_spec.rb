require 'rails_helper'

describe SearchObserver do

  def get_row(post_id)
    SqlBuilder.map_exec(
      OpenStruct,
      "select * from post_search_data where post_id = :post_id",
      post_id: post_id
    ).first
  end

  it 'correctly indexes chinese' do
    SiteSetting.default_locale = 'zh_CN'
    data = "你好世界"
    expect(data.split(" ").length).to eq(1)

    SearchObserver.update_posts_index(99, "你好世界", "", nil)

    row = get_row(99)
    expect(row.raw_data.split(' ').length).to eq(2)
  end

  it 'correctly indexes a post' do
    data = "<a>This</a> is a test"

    SearchObserver.update_posts_index(99, data, "", nil)

    row = get_row(99)

    expect(row.raw_data).to eq("This is a test")
    expect(row.locale).to eq("en")

    SearchObserver.update_posts_index(99, "tester", "", nil)

    row = get_row(99)

    expect(row.raw_data).to eq("tester")
  end
end
