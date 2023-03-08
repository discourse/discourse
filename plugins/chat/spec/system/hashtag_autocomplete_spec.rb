# frozen_string_literal: true

describe "Using #hashtag autocompletion to search for and lookup channels",
         type: :system,
         js: true do
  fab!(:user) { Fabricate(:user) }
  fab!(:channel1) { Fabricate(:chat_channel, name: "Music Lounge", slug: "music") }
  fab!(:channel2) { Fabricate(:chat_channel, name: "Random", slug: "random") }
  fab!(:category) { Fabricate(:category, name: "Raspberry", slug: "raspberry-beret") }
  fab!(:tag) { Fabricate(:tag, name: "razed") }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:message1) { Fabricate(:chat_message, chat_channel: channel1) }
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_drawer_page) { PageObjects::Pages::ChatDrawer.new }
  let(:chat_channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.enable_experimental_hashtag_autocomplete = true

    chat_system_bootstrap(user, [channel1, channel2])
    sign_in(user)
  end

  it "searches for channels, categories, and tags with # and prioritises channels in the results" do
    chat_page.visit_channel(channel1)
    chat_channel_page.type_in_composer("this is #ra")
    expect(page).to have_css(
      ".hashtag-autocomplete .hashtag-autocomplete__option .hashtag-autocomplete__link",
      count: 3,
    )
    hashtag_results = page.all(".hashtag-autocomplete__link", count: 3)
    expect(hashtag_results.map(&:text).map { |r| r.gsub("\n", " ") }).to eq(
      ["Random", "Raspberry", "razed (x0)"],
    )
  end

  it "searches for channels as well with # in a topic composer and deprioritises them" do
    topic_page.visit_topic_and_open_composer(topic)
    expect(topic_page).to have_expanded_composer
    topic_page.type_in_composer("something #ra")
    expect(page).to have_css(
      ".hashtag-autocomplete .hashtag-autocomplete__option .hashtag-autocomplete__link",
      count: 3,
    )
    hashtag_results = page.all(".hashtag-autocomplete__link", count: 3)
    expect(hashtag_results.map(&:text).map { |r| r.gsub("\n", " ") }).to eq(
      ["Raspberry", "razed (x0)", "Random"],
    )
  end

  it "cooks the hashtags for channels, categories, and tags serverside when the chat message is saved to the database" do
    chat_page.visit_channel(channel1)
    chat_channel_page.type_in_composer(
      "this is #random and this is #raspberry-beret and this is #razed which is cool",
    )
    chat_channel_page.click_send_message

    message = nil
    try_until_success do
      message =
        ChatMessage.find_by(
          user: user,
          message: "this is #random and this is #raspberry-beret and this is #razed which is cool",
        )
      expect(message).not_to eq(nil)
    end
    expect(chat_channel_page).to have_message(id: message.id)

    cooked_hashtags = page.all(".hashtag-cooked", count: 3)

    expect(cooked_hashtags[0]["outerHTML"]).to eq(<<~HTML.chomp)
    <a class=\"hashtag-cooked\" href=\"#{channel2.relative_url}\" data-type=\"channel\" data-slug=\"random\"><svg class=\"fa d-icon d-icon-comment svg-icon svg-node\"><use href=\"#comment\"></use></svg><span>Random</span></a>
    HTML
    expect(cooked_hashtags[1]["outerHTML"]).to eq(<<~HTML.chomp)
    <a class=\"hashtag-cooked\" href=\"#{category.url}\" data-type=\"category\" data-slug=\"raspberry-beret\"><svg class=\"fa d-icon d-icon-folder svg-icon svg-node\"><use href=\"#folder\"></use></svg><span>Raspberry</span></a>
    HTML
    expect(cooked_hashtags[2]["outerHTML"]).to eq(<<~HTML.chomp)
    <a class=\"hashtag-cooked\" href=\"#{tag.url}\" data-type=\"tag\" data-slug=\"razed\"><svg class=\"fa d-icon d-icon-tag svg-icon svg-node\"><use href=\"#tag\"></use></svg><span>razed</span></a>
    HTML
  end
end
