import { getOwner } from "@ember/owner";
import { click, render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import PollBreakdownModal from "discourse/plugins/poll/discourse/components/modal/poll-breakdown";

module("Poll | Component | PollBreakdownModal", function (hooks) {
  setupRenderingTest(hooks);

  test("uses the hover color for the highlighted option", async function (assert) {
    this.siteSettings.poll_groupable_user_fields = "occupation";
    pretender.get("/polls/grouped_poll_results.json", () =>
      response({ grouped_results: [] })
    );
    const model = {
      post: { id: 1, topic: { title: "A topic" } },
      poll: {
        name: "poll",
        title: "Favorite color",
        voters: 4,
        options: [
          { id: "a", html: "Red", votes: 1 },
          { id: "b", html: "Blue", votes: 3 },
        ],
      },
    };
    await render(<template><ModalContainer /></template>);
    getOwner(this).lookup("service:modal").show(PollBreakdownModal, { model });
    await settled();

    const swatch =
      ".poll-breakdown-option:nth-child(2) .poll-breakdown-option-color";
    const baseStyle = document.querySelector(swatch).getAttribute("style");

    await triggerEvent(".poll-breakdown-option:nth-child(2)", "mouseover");

    assert
      .dom(swatch)
      .hasAttribute("style", /^background: (?!undefined)\S+;$/, "has a color");
    assert.notStrictEqual(
      document.querySelector(swatch).getAttribute("style"),
      baseStyle,
      "differs from the base color"
    );
  });

  test("shows each option's share and switches to counts", async function (assert) {
    this.siteSettings.poll_groupable_user_fields = "occupation";
    pretender.get("/polls/grouped_poll_results.json", () =>
      response({ grouped_results: [] })
    );
    const model = {
      post: { id: 1, topic: { title: "A topic" } },
      poll: {
        name: "poll",
        title: "Favorite color",
        voters: 4,
        options: [
          { id: "a", html: "Red", votes: 1 },
          { id: "b", html: "Blue", votes: 3 },
        ],
      },
    };
    await render(<template><ModalContainer /></template>);
    getOwner(this).lookup("service:modal").show(PollBreakdownModal, { model });
    await settled();

    assert.dom(".poll-breakdown-title").hasText("Favorite color");
    assert
      .dom(".poll-breakdown-option:nth-child(2) .poll-breakdown-option-count")
      .hasText("75.0%", "shows percentages by default");

    await click(".modal-tab.count");

    assert
      .dom(".poll-breakdown-option:nth-child(2) .poll-breakdown-option-count")
      .hasText("3", "shows vote counts on the count tab");
  });
});
