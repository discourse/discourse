import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { registerHashtagType } from "discourse/lib/hashtag-type-registry";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import groupChatTranscripts from "discourse/plugins/chat/discourse/lib/group-chat-transcripts";
import ChannelHashtagType from "discourse/plugins/chat/discourse/lib/hashtag-types/channel";

const site = { hashtag_icons: { channel: "comment" } };

function render(html) {
  const element = document.createElement("div");
  element.innerHTML = html;
  groupChatTranscripts(element, { site });
  return element;
}

module("Unit | lib | group-chat-transcripts", function (hooks) {
  setupTest(hooks);

  test("groups a multi-author transcript under one channel header", function (assert) {
    const element = render(`
      <div class="chat-transcript chat-transcript-chained" data-channel-name="general" data-channel-id="7" data-multiquote="true">
        <div class="chat-transcript-meta">Originally sent in <a href="/chat/c/-/7">general</a></div>
      </div>
      <div class="chat-transcript chat-transcript-chained"></div>
      <div class="chat-transcript chat-transcript-chained"></div>
    `);

    const groups = element.querySelectorAll(".chat-transcript-group");
    assert.strictEqual(groups.length, 1);
    assert
      .dom(".chat-transcript-group__body > .chat-transcript", groups[0])
      .exists({ count: 3 });
    assert
      .dom(".chat-transcript-group__channel", groups[0])
      .hasText("general")
      .hasAttribute("href", "/chat/c/-/7");
    assert.dom(".chat-transcript-meta", groups[0]).doesNotExist();
    assert
      .dom(".chat-transcript-group__body", groups[0])
      .hasAttribute("role", "region")
      .hasAttribute("tabindex", "0")
      .hasAria("label", "Transcript from general");
  });

  test("moves a single quote's channel link into the header", function (assert) {
    const element = render(`
      <div class="chat-transcript" data-channel-name="general" data-channel-id="7">
        <div class="chat-transcript-user"><a class="chat-transcript-channel" href="/chat/c/-/7">#general</a></div>
      </div>
    `);

    assert.dom(".chat-transcript-group__channel", element).hasText("general");
    assert.dom(".chat-transcript-channel", element).doesNotExist();
  });

  test("groups a single author's messages split around a thread", function (assert) {
    const element = render(`
      <div class="chat-transcript" data-channel-name="general" data-channel-id="7" data-multiquote="true" data-thread-id="3"></div>
      <div class="chat-transcript" data-channel-id="7"></div>
    `);

    assert.dom(".chat-transcript-group", element).exists({ count: 1 });
    assert
      .dom(".chat-transcript-group__body > .chat-transcript", element)
      .exists({ count: 2 });
  });

  test("moves a sole thread's title into the header", function (assert) {
    const element = render(`
      <div class="chat-transcript" data-channel-name="general" data-channel-id="7" data-thread-id="3">
        <details>
          <summary>
            <div class="chat-transcript-thread">
              <div class="chat-transcript-thread-header"><span class="chat-transcript-thread-header__title">Ideas</span></div>
            </div>
          </summary>
          <div class="chat-transcript chat-transcript-chained"></div>
        </details>
      </div>
    `);

    assert
      .dom(
        ".chat-transcript-group__channel + .chat-transcript-group__thread",
        element
      )
      .hasText("Ideas");
    assert.dom(".chat-transcript-thread-header", element).doesNotExist();
  });

  test("links thread titles to the thread", function (assert) {
    const element = render(`
      <div class="chat-transcript" data-channel-name="general" data-channel-id="7" data-thread-id="3">
        <details>
          <summary>
            <div class="chat-transcript-thread">
              <div class="chat-transcript-thread-header"><span class="chat-transcript-thread-header__title">Ideas</span></div>
              <div class="chat-transcript-datetime"><a href="/chat/c/-/7/1" title="t1">first</a></div>
            </div>
          </summary>
        </details>
      </div>
    `);

    assert
      .dom(".chat-transcript-thread-header__title > a", element)
      .hasText("Ideas")
      .hasAttribute("href", "/chat/c/-/7/t/3");
  });

  test("keeps a thread's title inline when the transcript has more", function (assert) {
    const element = render(`
      <div class="chat-transcript" data-channel-name="general" data-channel-id="7" data-thread-id="3">
        <details>
          <summary>
            <div class="chat-transcript-thread">
              <div class="chat-transcript-thread-header"><span class="chat-transcript-thread-header__title">Ideas</span></div>
            </div>
          </summary>
        </details>
      </div>
      <div class="chat-transcript" data-channel-id="7"></div>
    `);

    assert.dom(".chat-transcript-group__thread", element).doesNotExist();
    assert.dom(".chat-transcript-thread-header", element).hasText("Ideas");
  });

  test("keeps adjacent separate quotes in separate groups", function (assert) {
    const element = render(`
      <div class="chat-transcript" data-channel-name="general" data-channel-id="7"></div>
      <div class="chat-transcript" data-channel-name="random" data-channel-id="8"></div>
    `);

    assert.dom(".chat-transcript-group", element).exists({ count: 2 });
  });

  test("expands threads, keeping replies inside their transcript", function (assert) {
    const element = render(`
      <div class="chat-transcript" data-channel-name="general" data-channel-id="7" data-thread-id="1">
        <details>
          <summary><div class="chat-transcript-thread"></div></summary>
          <div class="chat-transcript chat-transcript-chained"></div>
        </details>
      </div>
    `);

    assert
      .dom(".chat-transcript-group__body > .chat-transcript", element)
      .exists({ count: 1 });
    assert.dom("details, summary", element).doesNotExist();
    assert
      .dom(
        "[data-thread-id] > .chat-transcript-thread + .chat-transcript",
        element
      )
      .exists();
  });

  test("links every timestamp in the transcript to its message", function (assert) {
    const element = render(`
      <div class="chat-transcript chat-transcript-chained" data-message-id="1" data-channel-name="general" data-channel-id="7" data-thread-id="9">
        <details>
          <summary>
            <div class="chat-transcript-datetime"><a href="/chat/c/-/7/1" title="t1">first</a></div>
          </summary>
          <div class="chat-transcript chat-transcript-chained" data-message-id="2">
            <div class="chat-transcript-datetime"><span title="t2">reply</span></div>
          </div>
        </details>
      </div>
      <div class="chat-transcript chat-transcript-chained" data-message-id="3">
        <div class="chat-transcript-datetime"><span title="t3">third</span></div>
      </div>
    `);

    assert
      .dom("[data-message-id='1'] .chat-transcript-datetime > a", element)
      .hasAttribute("href", "/chat/c/-/7/1");
    assert
      .dom("[data-message-id='2'] .chat-transcript-datetime > a", element)
      .hasAttribute("href", "/chat/c/-/7/t/9/2")
      .hasAttribute("title", "t2")
      .hasText("reply");
    assert
      .dom("[data-message-id='3'] .chat-transcript-datetime > a", element)
      .hasAttribute("href", "/chat/c/-/7/3");
  });

  test("leaves archive timestamps unlinked", function (assert) {
    const element = render(`
      <div class="chat-transcript chat-transcript-chained" data-message-id="1" data-channel-name="general" data-channel-id="7">
        <div class="chat-transcript-datetime"><span title="t1">first</span></div>
      </div>
      <div class="chat-transcript chat-transcript-chained" data-message-id="2">
        <div class="chat-transcript-datetime"><span title="t2">second</span></div>
      </div>
    `);

    assert.dom(".chat-transcript-datetime a", element).doesNotExist();
  });

  test("links the avatar and username to the user card", function (assert) {
    const element = render(`
      <div class="chat-transcript" data-username="Bruce" data-channel-name="general" data-channel-id="7">
        <div class="chat-transcript-user">
          <div class="chat-transcript-user-avatar"><img class="avatar"></div>
          <div class="chat-transcript-username">Bruce</div>
        </div>
      </div>
    `);

    assert
      .dom(".chat-transcript-username > a", element)
      .hasText("Bruce")
      .hasAttribute("href", "/u/bruce")
      .hasAttribute("data-user-card", "Bruce");
    assert
      .dom(".chat-transcript-user-avatar > a", element)
      .hasAttribute("data-user-card", "Bruce")
      .hasAttribute("tabindex", "-1");
    assert.dom(".chat-transcript-user-avatar > a > img", element).exists();
  });

  test("shows the emoji of a channel the user hasn't loaded", async function (assert) {
    const channelType = new ChannelHashtagType(this.owner);
    // skips the color lookup, which this test doesn't cover
    channelType.loadedIds.add(42);
    registerHashtagType("channel", channelType);
    pretender.get("/hashtags/by-ids", () =>
      response({ channel: [{ id: 42, emoji: "tada" }] })
    );

    const element = render(`
      <div class="chat-transcript" data-channel-name="general" data-channel-id="42"></div>
    `);
    await settled();

    assert
      .dom(".chat-transcript-group__channel > img.emoji", element)
      .hasAttribute("title", "tada");
  });

  test("is idempotent", function (assert) {
    const element = render(`
      <div class="chat-transcript" data-channel-name="general" data-channel-id="7"></div>
    `);
    groupChatTranscripts(element, { site });

    assert.dom(".chat-transcript-group", element).exists({ count: 1 });
  });
});
