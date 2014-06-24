require 'spec_helper'

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
    data.split(" ").length.should == 1

    SearchObserver.update_posts_index(99, "你好世界", "", nil)

    row = get_row(99)
    row.raw_data.split(' ').length.should == 2
  end

  it 'correctly indexes a post' do
    data = "<a>This</a> is a test"

    SearchObserver.update_posts_index(99, data, "", nil)

    row = get_row(99)

    row.raw_data.should == "This is a test"
    row.locale.should == "en"

    SearchObserver.update_posts_index(99, "tester", "", nil)

    row = get_row(99)

    row.raw_data.should == "tester"
  end
end
