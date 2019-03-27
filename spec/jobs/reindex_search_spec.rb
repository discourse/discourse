require 'rails_helper'

describe Jobs::ReindexSearch do
  before { SearchIndexer.enable }
  after { SearchIndexer.disable }

  let(:locale) { 'fr' }
  # This works since test db has a small record less than limit.
  # Didn't check `topic` because topic doesn't have posts in fabrication
  # thus no search data
  %w(post category user).each do |m|
    it "should rebuild `#{m}` when default_locale changed" do
      SiteSetting.default_locale = 'en'
      model = Fabricate(m.to_sym)
      SiteSetting.default_locale = locale
      subject.execute({})
      expect(model.send("#{m}_search_data").locale).to eq locale
    end

    it "should rebuild `#{m}` when INDEX_VERSION changed" do
      model = Fabricate(m.to_sym)
      # so that search data can be reindexed
      search_data = model.send("#{m}_search_data")
      search_data.update_attributes!(version: 0)
      model.reload

      subject.execute({})
      expect(model.send("#{m}_search_data").version).to eq Search::INDEX_VERSION
    end
  end

  it "should clean up post_search_data of posts with empty raw" do
    post = Fabricate(:post)
    post2 = Fabricate(:post, post_type: Post.types[:small_action])
    post2.raw = ""
    post2.save!(validate: false)

    expect { subject.execute({}) }.to change { PostSearchData.count }.by(-1)
    expect(Post.all).to contain_exactly(post, post2)
    expect(PostSearchData.all).to contain_exactly(post.post_search_data)
  end
end
