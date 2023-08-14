# frozen_string_literal: true

require "rails_helper"

describe Chat::OneboxHandler do
  fab!(:chat_channel) { Fabricate(:category_channel) }
  fab!(:user) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user, active: false) }
  fab!(:user_3) { Fabricate(:user, staged: true) }
  fab!(:user_4) { Fabricate(:user, suspended_till: 3.weeks.from_now) }

  fab!(:chat_message) do
    Fabricate(:chat_message, chat_channel: chat_channel, user: user, message: "Hello world!")
  end

  let(:chat_url) { "#{Discourse.base_url}/chat/c/-/#{chat_channel.id}" }

  context "when regular onebox" do
    it "renders channel, excluding inactive, staged, and suspended users" do
      chat_channel.add(user)
      chat_channel.add(user_2)
      chat_channel.add(user_3)
      chat_channel.add(user_4)
      Chat::Channel.ensure_consistency!

      onebox_html = Chat::OneboxHandler.handle(chat_url, { channel_id: chat_channel.id })

      expect(onebox_html).to match_html <<~HTML
        <aside class="onebox chat-onebox">
          <article class="onebox-body chat-onebox-body">
            <h3 class="chat-onebox-title">
              <a href="#{chat_url}">
                <span class="category-chat-badge" style="color: ##{chat_channel.chatable.color}">
                  <svg class="fa d-icon d-icon-d-chat svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#d-chat"></use></svg>
               </span>
                <span class="clear-badge">#{chat_channel.name}</span>
              </a>
            </h3>
            <div class="chat-onebox-members-count">1 member</div>
            <div class="chat-onebox-members">
             <a class="trigger-user-card" data-user-card="#{user.username}" aria-hidden="true" tabindex="-1">
               <img loading="lazy" alt="#{user.username}" width="30" height="30" src="#{user.avatar_template_url.gsub("{size}", "60")}" class="avatar">
             </a>
            </div>
          </article>
      </aside>

      HTML
    end

    it "renders messages" do
      onebox_html =
        Chat::OneboxHandler.handle(
          "#{chat_url}/#{chat_message.id}",
          { channel_id: chat_channel.id, message_id: chat_message.id },
        )

      expect(onebox_html).to match_html <<~HTML
        <div class="chat-transcript" data-message-id="#{chat_message.id}" data-username="#{user.username}" data-datetime="#{chat_message.created_at.iso8601}" data-channel-name="#{chat_channel.name}" data-channel-id="#{chat_channel.id}">
        <div class="chat-transcript-user">
          <div class="chat-transcript-user-avatar">
            <a class="trigger-user-card" data-user-card="#{user.username}" aria-hidden="true" tabindex="-1">
              <img loading="lazy" alt="#{user.username}" width="20" height="20" src="#{user.avatar_template_url.gsub("{size}", "20")}" class="avatar">
            </a>
          </div>
          <div class="chat-transcript-username">#{user.username}</div>
            <div class="chat-transcript-datetime">
              <a href="#{chat_url}/#{chat_message.id}" title="#{chat_message.created_at}">#{chat_message.created_at}</a>
            </div>
            <a class="chat-transcript-channel" href="/chat/c/-/#{chat_channel.id}">
              <span class="category-chat-badge" style="color: ##{chat_channel.chatable.color}">
                <svg class="fa d-icon d-icon-d-chat svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#d-chat"></use></svg>
              </span>
              #{chat_channel.name}
            </a>
          </div>
        <div class="chat-transcript-messages"><p>Hello world!</p></div>
      </div>
      HTML
    end
  end
end
