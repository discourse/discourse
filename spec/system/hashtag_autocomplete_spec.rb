# frozen_string_literal: true

describe "Using #hashtag autocompletion to search for and lookup categories and tags",
         type: :system,
         js: true do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:category) { Fabricate(:category, name: "Cool Category", slug: "cool-cat") }
  fab!(:tag) { Fabricate(:tag, name: "cooltag") }
  fab!(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.enable_experimental_hashtag_autocomplete = true
    sign_in user
  end

  def visit_topic_and_initiate_autocomplete
    topic_page.visit_topic_and_open_composer(topic)
    expect(topic_page).to have_expanded_composer
    topic_page.type_in_composer("something #co")
    expect(page).to have_css(
      ".hashtag-autocomplete .hashtag-autocomplete__option .hashtag-autocomplete__link",
      count: 2,
    )
  end

  it "searches for categories and tags with # and prioritises categories in the results" do
    visit_topic_and_initiate_autocomplete
    hashtag_results = page.all(".hashtag-autocomplete__link", count: 2)
    expect(hashtag_results.map(&:text)).to eq(["Cool Category", "cooltag x 0"])
  end

  it "cooks the selected hashtag clientside with the correct url and icon" do
    visit_topic_and_initiate_autocomplete
    hashtag_results = page.all(".hashtag-autocomplete__link", count: 2)
    hashtag_results[0].click
    expect(page).to have_css(".hashtag-cooked")
    cooked_hashtag = page.find(".hashtag-cooked")
    expect(cooked_hashtag[:href]).to eq("#{Discourse.base_url}#{category.url}")
    within cooked_hashtag do
      has_css?("svg.d-icon-folder")
    end
    visit_topic_and_initiate_autocomplete
    hashtag_results = page.all(".hashtag-autocomplete__link", count: 2)
    hashtag_results[1].click
    expect(page).to have_css(".hashtag-cooked")
    cooked_hashtag = page.find(".hashtag-cooked")
    expect(cooked_hashtag[:href]).to eq("#{Discourse.base_url}#{tag.url}")
    within cooked_hashtag do
      has_css?("svg.d-icon-tag")
    end
  end

  it "cooks the hashtags for tag and category correctly serverside when the post is saved to the database" do
    topic_page.visit_topic_and_open_composer(topic)
    expect(topic_page).to have_expanded_composer
    topic_page.type_in_composer("this is a #cool-cat category and a #cooltag tag")
    topic_page.send_reply
    expect(topic_page).to have_post_number(2)

    within topic_page.post_by_number(2) do
      cooked_hashtags = page.all(".hashtag-cooked", count: 2)

      expect(cooked_hashtags[0][:href]).to eq("#{Discourse.base_url}#{category.url}")
      expect(cooked_hashtags[1][:href]).to eq("#{Discourse.base_url}#{tag.url}")

      within cooked_hashtags[0] do
        has_css?("svg.d-icon-folder")
      end
      within cooked_hashtags[1] do
        has_css?("svg.d-icon-tag")
      end
    end
  end
end
