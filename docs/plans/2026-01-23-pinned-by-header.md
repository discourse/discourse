# Pinned By Header Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace system messages for pin/unpin with inline "Pinned by [username]" headers in the pinned messages list.

**Architecture:** Remove `post_system_message` step from pin/unpin services. Add `pinned_by` user object to serializer. Update frontend component to display the attribution header with "you" logic.

**Tech Stack:** Ruby (Rails services, serializers), Ember.js (Glimmer components), SCSS

---

### Task 1: Update PinMessage Service - Remove System Message

**Files:**
- Modify: `plugins/chat/app/services/chat/pin_message.rb:22`
- Modify: `plugins/chat/spec/services/chat/pin_message_spec.rb:66-73`

**Step 1: Remove the system message step from the service**

In `plugins/chat/app/services/chat/pin_message.rb`, remove line 22:

```ruby
# Remove this line:
step :post_system_message
```

And remove the `post_system_message` method (lines 54-68):

```ruby
# Remove this entire method:
def post_system_message(message:, guardian:)
  Chat::CreateMessage.call(
    guardian: Discourse.system_user.guardian,
    params: {
      chat_channel_id: message.chat_channel_id,
      message:
        I18n.t(
          "chat.channel.message_pinned",
          username: guardian.user.username,
          message_url: message.url,
          count: 1,
        ),
    },
  )
end
```

**Step 2: Update the spec to verify no system message is created**

In `plugins/chat/spec/services/chat/pin_message_spec.rb`, replace the "posts a system message" test (lines 66-73) with:

```ruby
it "does not post a system message" do
  expect { result }.not_to change { Chat::Message.where(user: Discourse.system_user).count }
end
```

**Step 3: Run the spec to verify**

Run: `bin/rspec plugins/chat/spec/services/chat/pin_message_spec.rb`
Expected: All tests pass

**Step 4: Commit**

```bash
git add plugins/chat/app/services/chat/pin_message.rb plugins/chat/spec/services/chat/pin_message_spec.rb
git commit -m "$(cat <<'EOF'
DEV: remove system message from pin_message service

System messages for pinning are being replaced with inline
"Pinned by" headers in the pinned messages list UI.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Update UnpinMessage Service - Remove System Message

**Files:**
- Modify: `plugins/chat/app/services/chat/unpin_message.rb:21`
- Modify: `plugins/chat/spec/services/chat/unpin_message_spec.rb:54-61`

**Step 1: Remove the system message step from the service**

In `plugins/chat/app/services/chat/unpin_message.rb`, remove line 21:

```ruby
# Remove this line:
step :post_system_message
```

And remove the `post_system_message` method (lines 45-59):

```ruby
# Remove this entire method:
def post_system_message(message:, guardian:)
  Chat::CreateMessage.call(
    guardian: Discourse.system_user.guardian,
    params: {
      chat_channel_id: message.chat_channel_id,
      message:
        I18n.t(
          "chat.channel.message_unpinned",
          username: guardian.user.username,
          message_url: message.url,
          count: 1,
        ),
    },
  )
end
```

**Step 2: Update the spec to verify no system message is created**

In `plugins/chat/spec/services/chat/unpin_message_spec.rb`, replace the "posts a system message" test (lines 54-61) with:

```ruby
it "does not post a system message" do
  expect { result }.not_to change { Chat::Message.where(user: Discourse.system_user).count }
end
```

**Step 3: Run the spec to verify**

Run: `bin/rspec plugins/chat/spec/services/chat/unpin_message_spec.rb`
Expected: All tests pass

**Step 4: Commit**

```bash
git add plugins/chat/app/services/chat/unpin_message.rb plugins/chat/spec/services/chat/unpin_message_spec.rb
git commit -m "$(cat <<'EOF'
DEV: remove system message from unpin_message service

System messages for unpinning are being replaced with inline
"Pinned by" headers in the pinned messages list UI.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Update PinnedMessageSerializer - Add pinned_by User

**Files:**
- Modify: `plugins/chat/app/serializers/chat/pinned_message_serializer.rb`

**Step 1: Add the pinned_by association to the serializer**

Replace the entire file content with:

```ruby
# frozen_string_literal: true

module Chat
  class PinnedMessageSerializer < ::ApplicationSerializer
    attributes :id, :chat_message_id, :pinned_at

    has_one :pinned_by, serializer: ::BasicUserSerializer, embed: :objects
    has_one :message, serializer: Chat::MessageSerializer, embed: :objects

    def pinned_at
      object.created_at
    end

    def pinned_by
      object.user
    end

    def message
      object.chat_message
    end
  end
end
```

**Step 2: Run related specs to verify nothing breaks**

Run: `bin/rspec plugins/chat/spec/services/chat/list_channel_pins_spec.rb`
Expected: All tests pass

**Step 3: Commit**

```bash
git add plugins/chat/app/serializers/chat/pinned_message_serializer.rb
git commit -m "$(cat <<'EOF'
DEV: add pinned_by user to PinnedMessageSerializer

Include the user who pinned the message so the frontend can
display "Pinned by [username]" attribution.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Add Frontend Translations

**Files:**
- Modify: `plugins/chat/config/locales/client.en.yml:59-64`

**Step 1: Add the new translation keys**

In `plugins/chat/config/locales/client.en.yml`, update the `pinned_messages` section (around line 59):

```yaml
      pinned_messages:
        title: "Pinned messages"
        close: "Close pinned messages"
        pinned_by_you: "Pinned by you"
        pinned_by_user: "Pinned by %{username}"
```

**Step 2: Lint the file**

Run: `bin/lint plugins/chat/config/locales/client.en.yml`
Expected: No errors

**Step 3: Commit**

```bash
git add plugins/chat/config/locales/client.en.yml
git commit -m "$(cat <<'EOF'
DEV: add translations for pinned by attribution

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Update ChatPinnedMessagesList Component

**Files:**
- Modify: `plugins/chat/assets/javascripts/discourse/components/chat-pinned-messages-list.gjs`

**Step 1: Update the component to show "Pinned by" header**

Replace the entire file with:

```javascript
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChatMessage from "discourse/plugins/chat/discourse/components/chat-message";
import ChatMessageModel from "discourse/plugins/chat/discourse/models/chat-message";

export default class ChatPinnedMessagesList extends Component {
  @service messageBus;
  @service chatApi;
  @service currentUser;

  @tracked pinnedMessages = this.args.pinnedMessages || [];

  subscribe = modifierFn(() => {
    const channel = this.args.channel;

    this.messageBus.subscribe(
      `/chat/${channel.id}`,
      this.onMessage,
      channel.channelMessageBusLastId
    );

    return () => {
      this.messageBus.unsubscribe(`/chat/${channel.id}`, this.onMessage);

      // Update timestamp both locally and on backend when component unmounts (drawer closes)
      if (channel.currentUserMembership) {
        channel.currentUserMembership.lastViewedPinsAt = new Date();
        channel.currentUserMembership.hasUnseenPins = false;

        // Persist to backend so it survives page reloads
        this.chatApi.markPinsAsRead(channel.id);
      }
    };
  });

  onMessage = (busData) => {
    switch (busData.type) {
      case "pin":
        this.handlePinMessage(busData);
        break;
      case "unpin":
        this.handleUnpinMessage(busData);
        break;
    }
  };

  isUnseen = (pin) => {
    if (!this.lastViewedPinsAt) {
      return true;
    }

    const pinnedAt = new Date(pin.pinned_at);
    const lastViewed = new Date(this.lastViewedPinsAt);
    return pinnedAt > lastViewed;
  };

  decorateMessage = (pin) => {
    pin.message.isUnseen = this.isUnseen(pin);
    return pin.message;
  };

  pinnedByText = (pin) => {
    if (pin.pinned_by?.id === this.currentUser?.id) {
      return i18n("chat.pinned_messages.pinned_by_you");
    }
    return i18n("chat.pinned_messages.pinned_by_user", {
      username: pin.pinned_by?.username,
    });
  };

  get lastViewedPinsAt() {
    return this.args.channel.currentUserMembership?.lastViewedPinsAt;
  }

  handlePinMessage(data) {
    const existingPin = this.pinnedMessages.find(
      (pin) => pin.message.id === data.chat_message_id
    );

    if (existingPin) {
      return;
    }

    this.chatApi.pinnedMessages(this.args.channel.id).then((response) => {
      this.pinnedMessages = response.pinned_messages.map((pin) => {
        const message = ChatMessageModel.create(this.args.channel, pin.message);
        message.channel = this.args.channel;
        return { ...pin, message };
      });

      // If current user pinned this message, update timestamp so it doesn't show as unseen
      if (
        this.args.channel.currentUserMembership &&
        data.pinned_by_id === this.currentUser.id
      ) {
        this.args.channel.currentUserMembership.lastViewedPinsAt = new Date();
      }
    });
  }

  handleUnpinMessage(data) {
    this.pinnedMessages = this.pinnedMessages.filter(
      (pin) => pin.message.id !== data.chat_message_id
    );
  }

  <template>
    <div
      class="chat-pinned-messages-list chat-messages-scroller"
      {{this.subscribe}}
    >
      <div class="chat-pinned-messages-list__items">
        {{#each this.pinnedMessages as |pin|}}
          <div class="chat-pinned-message">
            <div class="chat-pinned-message__pinned-by">
              {{icon "thumbtack"}}
              <span>{{this.pinnedByText pin}}</span>
            </div>
            <ChatMessage
              @message={{this.decorateMessage pin}}
              @context="pinned"
              @includeSeparator={{false}}
            />
          </div>
        {{else}}
          <div class="chat-pinned-messages-list__empty">
            {{i18n "chat.no_pinned_messages"}}
          </div>
        {{/each}}
      </div>
    </div>
  </template>
}
```

**Step 2: Lint the file**

Run: `bin/lint plugins/chat/assets/javascripts/discourse/components/chat-pinned-messages-list.gjs`
Expected: No errors

**Step 3: Commit**

```bash
git add plugins/chat/assets/javascripts/discourse/components/chat-pinned-messages-list.gjs
git commit -m "$(cat <<'EOF'
UX: show "Pinned by" attribution in pinned messages list

Display a header above each pinned message showing who pinned it.
Shows "Pinned by you" when current user pinned the message,
otherwise shows "Pinned by [username]".

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Add Styling for Pinned By Header

**Files:**
- Find and modify the SCSS file for chat-pinned-messages-list

**Step 1: Find the existing SCSS file**

Run: `find plugins/chat -name "*.scss" | xargs grep -l "chat-pinned-messages-list" | head -1`

**Step 2: Add the styling**

Add the following styles (exact location depends on step 1):

```scss
.chat-pinned-message {
  &__pinned-by {
    display: flex;
    align-items: center;
    gap: 0.25em;
    padding: 0.5em 1em 0;
    color: var(--primary-medium);
    font-size: var(--font-down-1);

    .d-icon {
      color: var(--primary-medium);
    }
  }
}
```

**Step 3: Lint the file**

Run: `bin/lint <path-to-scss-file>`
Expected: No errors

**Step 4: Commit**

```bash
git add <path-to-scss-file>
git commit -m "$(cat <<'EOF'
UX: style pinned by attribution header

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Remove Unused Server Translations

**Files:**
- Modify: `plugins/chat/config/locales/server.en.yml:164-169`

**Step 1: Remove the unused translation keys**

In `plugins/chat/config/locales/server.en.yml`, remove these lines (around 164-169):

```yaml
      message_pinned:
        one: "%{username} pinned a [message](%{message_url})."
        other: "%{username} pinned a [message](%{message_url})."
      message_unpinned:
        one: "%{username} unpinned a [message](%{message_url})."
        other: "%{username} unpinned a [message](%{message_url})."
```

**Step 2: Lint the file**

Run: `bin/lint plugins/chat/config/locales/server.en.yml`
Expected: No errors

**Step 3: Commit**

```bash
git add plugins/chat/config/locales/server.en.yml
git commit -m "$(cat <<'EOF'
DEV: remove unused pin/unpin system message translations

These translations are no longer used since system messages
were replaced with inline "Pinned by" headers.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Add System Spec for Pinned By Display

**Files:**
- Create: `plugins/chat/spec/system/pinned_messages_spec.rb` (or find existing)

**Step 1: Find existing pinned messages system spec or create new one**

Run: `find plugins/chat/spec/system -name "*pin*"`

**Step 2: Add test for pinned by display**

Add a test that verifies:
1. When user A pins a message, user A sees "Pinned by you"
2. When user B views the pinned messages, user B sees "Pinned by [user A's username]"

The exact implementation depends on existing test patterns found in step 1.

**Step 3: Run the system spec**

Run: `bin/rspec plugins/chat/spec/system/pinned_messages_spec.rb`
Expected: All tests pass

**Step 4: Commit**

```bash
git add plugins/chat/spec/system/pinned_messages_spec.rb
git commit -m "$(cat <<'EOF'
DEV: add system spec for pinned by attribution

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Final Verification

**Step 1: Run all chat specs**

Run: `bin/rspec plugins/chat/spec --seed random`
Expected: All tests pass

**Step 2: Run JS tests**

Run: `bin/qunit plugins/chat`
Expected: All tests pass

**Step 3: Lint all changed files**

Run: `bin/lint --fix --recent`
Expected: No errors
