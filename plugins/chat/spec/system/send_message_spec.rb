# frozen_string_literal: true

RSpec.describe "Send message", type: :system do
  fab!(:user_1) { Fabricate(:admin) }
  fab!(:user_2) { Fabricate(:admin) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    # simpler user search without having to worry about user search data
    SiteSetting.enable_names = false

    chat_system_bootstrap
  end

  context "with direct message channels" do
    context "when users are not following the channel" do
      fab!(:channel_1) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }

      before do
        channel_1.remove(user_1)
        channel_1.remove(user_2)
      end

      it "shows correct state" do
        sign_in(user_1)
        visit("/")

        expect(chat_page.sidebar).to have_no_direct_message_channel(channel_1)

        using_session(:user_2) do
          sign_in(user_2)
          visit("/")

          expect(chat_page.sidebar).to have_no_direct_message_channel(channel_1)
        end

        chat_page.open_new_message
        chat_page.message_creator.filter(user_2.username)
        chat_page.message_creator.click_row(user_2)

        expect(chat_page.sidebar).to have_direct_message_channel(channel_1)

        using_session(:user_2) do
          expect(chat_page.sidebar).to have_no_direct_message_channel(channel_1)
        end

        channel_page.send_message

        expect(chat_page.sidebar).to have_direct_message_channel(channel_1)

        using_session(:user_2) do
          expect(chat_page.sidebar).to have_direct_message_channel(channel_1, mention: true)
        end
      end
    end

    context "when users are following the channel" do
      fab!(:channel_1) { Fabricate(:direct_message_channel, users: [user_1, user_2]) }

      it "shows correct state" do
        sign_in(user_1)
        visit("/")

        expect(chat_page.sidebar).to have_direct_message_channel(channel_1)

        using_session(:user_2) do
          sign_in(user_2)
          visit("/")

          expect(chat_page.sidebar).to have_direct_message_channel(channel_1)
        end

        chat_page.open_new_message
        chat_page.message_creator.filter(user_2.username)
        chat_page.message_creator.click_row(user_2)

        expect(chat_page.sidebar).to have_direct_message_channel(channel_1)

        using_session(:user_2) do
          expect(chat_page.sidebar).to have_direct_message_channel(channel_1)
        end

        channel_page.send_message

        expect(chat_page.sidebar).to have_direct_message_channel(channel_1)

        using_session(:user_2) do
          expect(chat_page.sidebar).to have_direct_message_channel(channel_1, mention: true)
        end
      end
    end
  end

  context "when sending message from drawer" do
    let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }
    let(:topic_page) { PageObjects::Pages::Topic.new }

    fab!(:post_1) { Fabricate(:post) }
    fab!(:post_2) { Fabricate(:post, topic: post_1.topic) }
    fab!(:channel_1) { Fabricate(:chat_channel) }

    before do
      sign_in(user_1)
      channel_1.add(user_1)
      Jobs.run_immediately!
    end

    it "has topic context" do
      tested_context = {}
      blk = Proc.new { |message, channel, user, context| tested_context = context }

      begin
        DiscourseEvent.on(:chat_message_created, &blk)
        topic_page.visit_topic(post_1.topic)
        chat_page.open_from_header
        drawer_page.open_channel(channel_1)
        channel_page.send_message

        try_until_success do
          expect(tested_context.dig(:context, :post_ids)).to eq([post_1.id, post_2.id])
          expect(tested_context.dig(:context, :topic_id)).to eq(post_1.topic_id)
        end
      ensure
        DiscourseEvent.off(:chat_message_created, &blk)
      end
    end
  end
end
