# frozen_string_literal: true

RSpec.describe "Channel message selection", type: :system do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }
  let(:image) do
    Fabricate(
      :upload,
      original_filename: "test_image.jpg",
      width: 400,
      height: 300,
      extension: "jpg",
    )
  end

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
    message_1.uploads = [image]
  end

  it "can collapse/expand an image and still have lightbox working" do
    SiteSetting.experimental_lightbox = false
    chat.visit_channel(channel_1)

    find(".chat-message-collapser-button").click
    expect(page).to have_css(".chat-message-collapser-body.hidden", visible: :hidden)
    find(".chat-message-collapser-button").click
    expect(page).to have_no_css(".chat-message-collapser-body.hidden")
    find(".chat-img-upload").click

    # visible false is because the upload doesn’t exist but it's enough to know lightbox is working
    expect(page).to have_css(".mfp-image-holder img[src*='#{image.url}']", visible: :hidden)
  end

  it "can open image in lightbox when using PhotoSwipe" do
    SiteSetting.experimental_lightbox = true

    chat.visit_channel(channel_1)
    find(".chat-img-upload").click

    expect(page).to have_css(".pswp")
  end
end
