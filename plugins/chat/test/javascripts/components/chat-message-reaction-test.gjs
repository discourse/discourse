import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { blur, click, focus, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import ChatMessageReaction from "discourse/plugins/chat/discourse/components/chat-message-reaction";
import ChatFabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module("Component | ChatMessageReaction", function (hooks) {
  setupRenderingTest(hooks);

  test("adds reacted class when user reacted", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart" reacted=true}} />
      </template>
    );

    assert.dom(".chat-message-reaction.reacted").exists();
  });

  test("adds reaction name as class", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart"}} />
      </template>
    );

    assert.dom(`.chat-message-reaction[data-emoji-name="heart"]`).exists();
  });

  test("title/alt attributes", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart"}} />
      </template>
    );

    assert.dom(".chat-message-reaction").hasAttribute("title", ":heart:");
    assert.dom(".chat-message-reaction img").hasAttribute("alt", ":heart:");
  });

  test("is reachable by keyboard unless explicitly non-interactive", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart"}} />
      </template>
    );

    assert
      .dom(".chat-message-reaction")
      .hasAttribute(
        "tabindex",
        "0",
        "an omitted @interactive still means interactive"
      );

    await render(
      <template>
        <ChatMessageReaction
          @reaction={{hash emoji="heart"}}
          @interactive={{false}}
        />
      </template>
    );

    assert
      .dom(".chat-message-reaction")
      .hasAttribute(
        "tabindex",
        "-1",
        "a display-only reaction stays out of the tab order"
      );
  });

  test("opens the users popup on focus, not only on hover", async function (assert) {
    this.siteSettings.enable_new_chat_reactions_popup = true;

    const fabricators = new ChatFabricators(getOwner(this));
    const message = fabricators.message();
    const reaction = fabricators.reaction({ emoji: "heart", count: 1 });

    pretender.get(
      `/chat/${message.channel.id}/${message.id}/reactions-users`,
      () => response({ users: [], total_rows: 0 })
    );

    await render(
      <template>
        <DMenus />
        <ChatMessageReaction @reaction={{reaction}} @message={{message}} />
      </template>
    );

    await focus(".chat-message-reaction");

    assert
      .dom("[data-identifier='chat-message-reaction-users']")
      .exists("focusing the reaction opens the popup");

    await blur(".chat-message-reaction");

    assert
      .dom("[data-identifier='chat-message-reaction-users']")
      .doesNotExist("leaving the reaction closes it again");
  });

  test("names itself as a reaction rather than just an emoji", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart" count=3}} />
      </template>
    );

    assert
      .dom(".chat-message-reaction")
      .hasAria(
        "label",
        i18n("chat.reactions.counted", { emoji: "heart", count: 3 }),
        "a counted reaction is named by what it stands for"
      );
  });

  test("names itself by its action where it is only a way to react", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction
          @reaction={{hash emoji="heart"}}
          @showCount={{false}}
        />
      </template>
    );

    assert
      .dom(".chat-message-reaction")
      .hasAria("label", i18n("chat.reactions.add", { emoji: "heart" }));
  });

  test("reports whether the reaction is the current user's", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction
          @reaction={{hash emoji="heart" count=1 reacted=true}}
        />
        <ChatMessageReaction
          @reaction={{hash emoji="+1" count=1 reacted=false}}
        />
      </template>
    );

    assert
      .dom("[data-emoji-name='heart']")
      .hasAria("pressed", "true", "a reaction the user added is pressed");
    assert
      .dom("[data-emoji-name='+1']")
      .hasAria("pressed", "false", "one they have not added is not pressed");
  });

  test("is not a toggle where it is only a way to react", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction
          @reaction={{hash emoji="heart" reacted=true}}
          @showCount={{false}}
        />
      </template>
    );

    // named for its action, so announcing a pressed state on top of that describes
    // neither the control nor its effect
    assert.dom(".chat-message-reaction").doesNotHaveAria("pressed");
    assert
      .dom(".chat-message-reaction")
      .hasAria(
        "label",
        i18n("chat.reactions.remove", { emoji: "heart" }),
        "and the action it names is the one it performs"
      );
  });

  test("describes who reacted, without folding them into the name", async function (assert) {
    const reaction = {
      emoji: "heart",
      count: 2,
      users: [
        { id: 1, username: "bob" },
        { id: 2, username: "jane" },
      ],
    };

    await render(
      <template><ChatMessageReaction @reaction={{reaction}} /></template>
    );

    const descriptionId = document
      .querySelector(".chat-message-reaction")
      .getAttribute("aria-describedby");

    assert.dom(`#${descriptionId}`).hasClass("sr-only");
    assert.dom(`#${descriptionId}`).includesText("bob");
    assert
      .dom(`.chat-message-reaction #${descriptionId}`)
      .doesNotExist("the description sits outside the button");
  });

  test("has no description when nobody has reacted", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart" count=0}} />
      </template>
    );

    assert
      .dom(".chat-message-reaction")
      .doesNotHaveAttribute("aria-describedby");
    assert.dom(".sr-only").doesNotExist();
  });

  test("count of reactions", async function (assert) {
    this.set("count", 0);

    await render(
      <template>
        <ChatMessageReaction
          @reaction={{hash emoji="heart" count=this.count}}
        />
      </template>
    );

    assert.dom(".chat-message-reaction .count").doesNotExist();

    this.set("count", 2);
    assert.dom(".chat-message-reaction .count").hasText("2");
  });

  test("reaction’s image", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart"}} />
      </template>
    );

    assert.dom(".chat-message-reaction img").hasAttribute("src", /heart\.png/);
  });

  test("click action", async function (assert) {
    this.set("count", 0);
    this.set("react", () => {
      this.set("count", 1);
    });

    await render(
      <template>
        <ChatMessageReaction
          class="show"
          @reaction={{hash emoji="heart" count=this.count}}
          @onReaction={{this.react}}
        />
      </template>
    );

    assert.dom(".chat-message-reaction .count").doesNotExist();

    await click(".chat-message-reaction");
    assert.dom(".chat-message-reaction .count").hasText("1");
  });
});
