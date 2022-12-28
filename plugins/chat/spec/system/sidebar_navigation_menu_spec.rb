# frozen_string_literal: true

RSpec.describe "Sidebar navigation menu", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap

    sign_in(current_user)
  end

  context "when displaying the public channels section" do
    fab!(:channel_1) { Fabricate(:chat_channel) }

    before { channel_1.add(current_user) }

    it "displays correct channels section title" do
      visit("/")

      expect(page).to have_css(
        ".sidebar-section-chat-channels .sidebar-section-header-text",
        text: I18n.t("js.chat.chat_channels"),
      )
    end

    it "displays the correct hash icon prefix" do
      visit("/")

      expect(page).to have_css(
        ".sidebar-section-chat-channels .sidebar-section-link-#{channel_1.slug} .sidebar-section-link-prefix svg.prefix-icon.d-icon-hashtag",
      )
    end

    it "channel link has the correct href" do
      visit("/")

      expect(page).to have_link(
        channel_1.name,
        href: "/chat/channel/#{channel_1.id}/#{channel_1.slug}",
      )
    end

    context "when the category is private" do
      fab!(:group_1) { Fabricate(:group) }
      fab!(:private_channel_1) { Fabricate(:private_category_channel, group: group_1) }

      before do
        group_1.add(current_user)
        private_channel_1.add(current_user)
      end

      it "has a lock badge" do
        visit("/")

        expect(page).to have_css(
          ".sidebar-section-chat-channels .sidebar-section-link-#{private_channel_1.slug} .sidebar-section-link-prefix svg.prefix-badge.d-icon-lock",
        )
      end
    end

    context "when the channel has an emoji in the title" do
      fab!(:channel_1) { Fabricate(:chat_channel, name: "test :heart:") }

      before { channel_1.add(current_user) }

      it "unescapes the emoji" do
        visit("/")

        expect(page).to have_css(
          ".sidebar-section-chat-channels .sidebar-section-link-#{channel_1.slug} .emoji",
        )
      end
    end

    context "when the channel is muted" do
      fab!(:channel_2) { Fabricate(:chat_channel) }

      before do
        Fabricate(
          :user_chat_channel_membership,
          user: current_user,
          chat_channel: channel_2,
          muted: true,
        )
      end

      it "has a muted class" do
        visit("/")

        expect(page).to have_css(
          ".sidebar-section-chat-channels .sidebar-section-link-#{channel_2.slug}.sidebar-section-link--muted",
        )
      end
    end

    context "when channel description contains malicious content" do
      before { channel_1.update!(description: "<script>alert('hello')</script>") }

      it "escapes the title attribute using it" do
        visit("/")

        expect(
          page.find(".sidebar-section-chat-channels .sidebar-section-link-#{channel_1.slug}")[
            "title"
          ],
        ).to eq("&lt;script&gt;alert(&#x27;hello&#x27;)&lt;/script&gt;")
      end
    end
  end

  context "when displaying the direct message channels section" do
    context "when the channel has two participants" do
      fab!(:other_user) { Fabricate(:user) }
      fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, other_user]) }

      it "displays other user avatar in prefix when two participants" do
        visit("/")

        expect(
          page.find(
            ".sidebar-section-chat-dms a.sidebar-section-link:nth-child(1) .sidebar-section-link-prefix img",
          )[
            "src"
          ],
        ).to include(other_user.username)
      end

      it "displays other user username as link text" do
        visit("/")

        expect(
          page.find(".sidebar-section-chat-dms a.sidebar-section-link:nth-child(1)"),
        ).to have_content(other_user.username)
      end

      context "when other user has status" do
        before do
          SiteSetting.enable_user_status = true
          other_user.set_status!("online", "heart")
        end

        it "displays the status" do
          visit("/")

          expect(
            page.find(".sidebar-section-chat-dms a.sidebar-section-link:nth-child(1)"),
          ).to have_css(".user-status")
        end
      end
    end

    context "when channel has more than 2 participants" do
      fab!(:user_1) { Fabricate(:user) }
      fab!(:user_2) { Fabricate(:user) }
      fab!(:dm_channel_1) do
        Fabricate(:direct_message_channel, users: [current_user, user_1, user_2])
      end

      it "displays all participants names" do
        visit("/")
        expect(
          page.find(
            ".sidebar-section-chat-dms a.sidebar-section-link:nth-child(1) .sidebar-section-link-content-text",
          ),
        ).to have_content("#{user_1.username}, #{user_2.username}")
      end
    end

    context "when username contains malicious content" do
      fab!(:other_user) { Fabricate(:user) }
      fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, other_user]) }

      before do
        other_user.username = "<script>alert('hello')</script>"
        other_user.save!(validate: false)
      end

      it "escapes the title attribute using it" do
        visit("/")

        expect(page.find(".sidebar-section-chat-dms .channel-#{dm_channel_1.id}")["title"]).to eq(
          "Chat with @&lt;script&gt;alert(&#x27;hello&#x27;)&lt;/script&gt;",
        )
      end
    end
  end
end
