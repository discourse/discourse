# frozen_string_literal: true

describe Chat::OneboxHandler do
  fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
  fab!(:private_channel) { Fabricate(:category_channel, chatable: private_category) }
  fab!(:public_channel) { Fabricate(:category_channel) }
  fab!(:user)
  fab!(:user_2) { Fabricate(:user, active: false) }
  fab!(:user_3) { Fabricate(:user, staged: true) }
  fab!(:user_4) { Fabricate(:user, suspended_till: 3.weeks.from_now) }

  let(:public_chat_url) { "#{Discourse.base_url}/chat/c/-/#{public_channel.id}" }
  let(:private_chat_url) { "#{Discourse.base_url}/chat/c/-/#{private_channel.id}" }
  let(:invalid_chat_url) { "#{Discourse.base_url}/chat/c/-/999" }

  describe "chat channel" do
    context "when valid" do
      it "renders channel onebox, excluding inactive, staged, and suspended users" do
        public_channel.add(user)
        public_channel.add(user_2)
        public_channel.add(user_3)
        public_channel.add(user_4)
        Chat::Channel.ensure_consistency!

        onebox_html = Chat::OneboxHandler.handle(public_chat_url, { channel_id: public_channel.id })

        expect(onebox_html).to match_html <<~HTML
          <aside class="onebox chat-onebox">
            <article class="onebox-body chat-onebox-body">
              <h3 class="chat-onebox-title">
                <a href="/chat/c/-/#{public_channel.id}">
                  <span class="category-chat-badge" style="color: ##{public_channel.chatable.color}">
                    <svg class="fa d-icon d-icon-d-chat svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#d-chat"></use></svg>
                  </span>
                  <span class="clear-badge">#{public_channel.name}</span>
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
    end

    context "when channel is private" do
      it "does not create a onebox" do
        onebox_html =
          Chat::OneboxHandler.handle(private_chat_url, { channel_id: private_channel.id })

        expect(onebox_html).to be_nil
      end
    end

    context "when channel does not exists" do
      it "does not raise an error" do
        onebox_html = Chat::OneboxHandler.handle(invalid_chat_url, { channel_id: 999 })

        expect(onebox_html).to be_nil
      end
    end
  end

  describe "chat message" do
    fab!(:public_message) do
      Fabricate(:chat_message, chat_channel: public_channel, user: user, message: "Hello world!")
    end
    fab!(:private_message) do
      Fabricate(:chat_message, chat_channel: private_channel, user: user, message: "Hello world!")
    end

    context "when valid" do
      it "renders message onebox" do
        onebox_html =
          Chat::OneboxHandler.handle(
            "#{public_chat_url}/#{public_message.id}",
            { channel_id: public_channel.id, message_id: public_message.id },
          )

        expect(onebox_html).to match_html <<~HTML
          <div class="chat-transcript" data-message-id="#{public_message.id}" data-username="#{user.username}" data-datetime="#{public_message.created_at.iso8601}" data-channel-name="#{public_channel.name}" data-channel-id="#{public_channel.id}">
            <div class="chat-transcript-user">
              <div class="chat-transcript-user-avatar">
                <a class="trigger-user-card" data-user-card="#{user.username}" aria-hidden="true" tabindex="-1">
                  <img loading="lazy" alt="#{user.username}" width="20" height="20" src="#{user.avatar_template_url.gsub("{size}", "20")}" class="avatar">
                </a>
              </div>
              <div class="chat-transcript-username">#{user.username}</div>
              <div class="chat-transcript-datetime">
                <a href="/chat/c/-/#{public_channel.id}/#{public_message.id}" title="#{public_message.created_at}">#{public_message.created_at}</a>
              </div>
              <a class="chat-transcript-channel" href="/chat/c/-/#{public_channel.id}">
                <span class="category-chat-badge" style="color: ##{public_channel.chatable.color}">
                  <svg class="fa d-icon d-icon-d-chat svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#d-chat"></use></svg>
                </span>
                #{public_channel.name}
              </a>
            </div>
            <div class="chat-transcript-messages"><p>Hello world!</p></div>
            <div class="chat-transcript-images onebox"></div>
          </div>
        HTML
      end
    end

    context "when channel is private" do
      it "does not create a onebox" do
        onebox_html =
          Chat::OneboxHandler.handle(
            "#{private_chat_url}/#{private_message.id}",
            { channel_id: private_channel.id, message_id: private_message.id },
          )

        expect(onebox_html).to be_nil
      end
    end

    context "when message does not exists" do
      it "does not raise an error" do
        onebox_html =
          Chat::OneboxHandler.handle(
            "#{public_chat_url}/999",
            { channel_id: public_channel.id, message_id: 999 },
          )

        expect(onebox_html).to be_nil
      end
    end
  end

  describe "chat thread" do
    fab!(:original_public_message) do
      Fabricate(:chat_message, user: user, chat_channel: public_channel, message: "Hello world!")
    end
    fab!(:public_thread) do
      Fabricate(:chat_thread, channel: public_channel, original_message: original_public_message)
    end
    fab!(:private_thread) { Fabricate(:chat_thread, channel: private_channel) }

    context "when valid" do
      it "renders thread onebox" do
        onebox_html =
          Chat::OneboxHandler.handle(
            "#{public_chat_url}/t/#{public_thread.id}",
            { channel_id: public_channel.id, thread_id: public_thread.id },
          )

        expect(onebox_html).to match_html <<~HTML
          <aside class="onebox chat-onebox">
            <article class="onebox-body chat-onebox-body">
              <div class="chat-transcript-user">
                <h3 class="chat-onebox-title">
                  <a href="/chat/c/-/#{public_channel.id}/t/#{public_thread.id}">
                    <span class="category-chat-badge" style="color: ##{public_channel.chatable.color}">
                      <svg class="fa d-icon d-icon-discourse-threads svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#discourse-threads"></use></svg>
                    </span>
                    <span class="clear-badge">#{public_thread.title}</span>
                  </a>
                </h3>
                <span class="thread-title-connector">in</span>
                <a href="/chat/c/-/#{public_channel.id}">
                  <span class="category-chat-badge" style="color: ##{public_channel.chatable.color}">
                    <svg class="fa d-icon d-icon-d-chat svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#d-chat"></use></svg>
                  </span>
                  <span class="clear-badge">#{public_channel.name}</span>
                </a>
              </div>
              <div class="chat-onebox-cooked"><p>Hello world!</p></div>
              <div class="chat-onebox-images onebox"></div>
            </article>
          </aside>
        HTML
      end
    end

    context "when channel is private" do
      it "does not create a onebox" do
        onebox_html =
          Chat::OneboxHandler.handle(
            "#{private_chat_url}/t/#{private_thread.id}",
            { channel_id: private_channel.id, thread_id: public_thread.id },
          )

        expect(onebox_html).to be_nil
      end
    end

    context "when thread does not exist" do
      it "creates a channel onebox" do
        public_channel.add(user)
        Chat::Channel.ensure_consistency!

        onebox_html =
          Chat::OneboxHandler.handle(
            "#{public_chat_url}/t/999",
            { channel_id: public_channel.id, thread_id: 999 },
          )

        expect(onebox_html).to match_html <<~HTML
          <aside class="onebox chat-onebox">
            <article class="onebox-body chat-onebox-body">
              <h3 class="chat-onebox-title">
                <a href="/chat/c/-/#{public_channel.id}">
                  <span class="category-chat-badge" style="color: ##{public_channel.chatable.color}">
                    <svg class="fa d-icon d-icon-d-chat svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use href="#d-chat"></use></svg>
                  </span>
                  <span class="clear-badge">#{public_channel.name}</span>
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
    end
  end
end
