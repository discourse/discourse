import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ChatChannelFilter from "discourse/plugins/chat/discourse/components/chat-channel-filter";

module("Integration | Component | ChatChannelFilter", function (hooks) {
  setupRenderingTest(hooks);

  test("Clear resets the result counter and navigation", async function (assert) {
    const channel = { id: 42 };
    let targetId;
    const loadTarget = (id) => (targetId = id);
    pretender.get("/chat/api/search", () =>
      response({ messages: [{ id: 2 }, { id: 1 }] })
    );

    await render(
      <template>
        <ChatChannelFilter
          @channel={{channel}}
          @isFiltering={{true}}
          @onLoadTargetMessageId={{loadTarget}}
        />
      </template>
    );

    const input = ".chat-channel__filter-bar input";
    const position = ".chat-channel__filter-position";
    const previous = ".chat-channel__prev-result";
    const next = ".chat-channel__next-result";
    await fillIn(input, "matching query");
    await click(previous);
    assert.dom(position).hasText("2 / 2", "the second result is selected");
    assert.strictEqual(targetId, 1, "the second result is the channel target");

    await click(".chat-channel__filter-bar .filter-input-clear-btn");

    assert.dom(input).hasValue("", "the query is cleared");
    assert.dom(position).doesNotExist("the result position is cleared");
    assert.dom(previous).doesNotExist("the previous control is removed");
    assert.dom(next).doesNotExist("the next control is removed");

    await fillIn(input, "another query");
    assert.dom(position).hasText("1 / 2", "a new query starts at result one");
  });
});
