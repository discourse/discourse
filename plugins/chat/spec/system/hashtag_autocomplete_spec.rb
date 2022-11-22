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

    # This is annoying, but we need to reset the hashtag data sources inbetween
    # tests, and since this is normally done in plugin.rb with the plugin API
    # there is not an easier way to do this.
    HashtagAutocompleteService.register_data_source("channel", Chat::ChatChannelHashtagDataSource)
    HashtagAutocompleteService.register_type_in_context("channel", "chat-composer", 200)
    HashtagAutocompleteService.register_type_in_context("category", "chat-composer", 100)
    HashtagAutocompleteService.register_type_in_context("tag", "chat-composer", 50)
    HashtagAutocompleteService.register_type_in_context("channel", "topic-composer", 10)

    chat_system_bootstrap(user, [channel1, channel2])
    sign_in(user)
  end

  it "searches for channels, categories, and tags with # and prioritises channels in the results" do
    chat_page.visit_channel(channel1)
    expect(chat_channel_page).to have_no_loading_skeleton
    chat_channel_page.type_in_composer("this is #ra")
    expect(page).to have_css(
      ".hashtag-autocomplete .hashtag-autocomplete__option .hashtag-autocomplete__link",
      count: 3,
    )
    hashtag_results = page.all(".hashtag-autocomplete__link", count: 3)
    expect(hashtag_results.map(&:text)).to eq(["Random", "Raspberry", "razed x 0"])
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
    expect(hashtag_results.map(&:text)).to eq(["Raspberry", "razed x 0", "Random"])
  end

  # TODO (martin) Commenting this out for now, we need to add the MessageBus
  # last_message_id to our chat subscriptions in JS for this to work, since it
  # relies on a MessageBus "sent" event to be published to substitute the
  # staged message ID for the real one.
  xit "cooks the hashtags for channels, categories, and tags serverside when the chat message is saved to the database" do
    chat_page.visit_channel(channel1)
    expect(chat_channel_page).to have_no_loading_skeleton
    chat_channel_page.type_in_composer("this is #random and this is #raspberry and this is #razed which is cool")
    chat_channel_page.click_send_message

    try_until_success do
      expect(ChatMessage.exists?(user: user, message: "this is #random and this is #raspberry and this is #razed which is cool")).to eq(true)
    end
    message = ChatMessage.where(user: user).last
    expect(chat_channel_page).to have_message(id: message.id)

    within chat_channel_page.message_by_id(message.id) do
      cooked_hashtags = page.all(".hashtag-cooked", count: 3)

      expect(cooked_hashtags[0]["outerHTML"]).to eq(<<~HTML.chomp)
      <a class=\"hashtag-cooked\" href=\"#{channel1.relative_url}\" data-type=\"channel\" data-slug=\"random\"><span><svg class=\"fa d-icon d-icon-comment svg-icon svg-node\"><use href=\"#comment\"></use></svg>Random</span></a>
      HTML
      expect(cooked_hashtags[1]["outerHTML"]).to eq(<<~HTML.chomp)
      <a class=\"hashtag-cooked\" href=\"#{category.url}\" data-type=\"category\" data-slug=\"raspberry\"><span><svg class=\"fa d-icon d-icon-folder svg-icon svg-node\"><use href=\"#folder\"></use></svg>raspberry</span></a>
      HTML
      expect(cooked_hashtags[2]["outerHTML"]).to eq(<<~HTML.chomp)
      <a class=\"hashtag-cooked\" href=\"#{tag.url}\" data-type=\"tag\" data-slug=\"razed\"><span><svg class=\"fa d-icon d-icon-tag svg-icon svg-node\"><use href=\"#tag\"></use></svg>razed</span></a>
      HTML
    end
  end
end
