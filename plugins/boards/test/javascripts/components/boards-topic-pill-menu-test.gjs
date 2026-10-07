import EmberObject from "@ember/object";
import { trustHTML } from "@ember/template";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DMenus from "discourse/float-kit/components/d-menus";
import renderTags from "discourse/lib/render-tags";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function membership({ boardId, boardName, cardId, columnTitle }) {
  return {
    board_id: boardId,
    board_name: boardName,
    board_slug: boardName.toLowerCase(),
    cards: [
      {
        card_id: cardId,
        column_id: 11,
        column_title: columnTitle,
        column_color: "0088cc",
        column_icon: "list",
      },
    ],
  };
}

module("Integration | boards topic pill menu", function (hooks) {
  setupRenderingTest(hooks);

  test("clicking the pill of a topic on several boards opens a menu of them", async function (assert) {
    const topic = EmberObject.create({
      board_memberships: [
        membership({
          boardId: 1,
          boardName: "Sales",
          cardId: 101,
          columnTitle: "In progress",
        }),
        membership({
          boardId: 2,
          boardName: "Support",
          cardId: 201,
          columnTitle: "Queued",
        }),
      ],
    });
    this.tags = trustHTML(renderTags(topic));

    await render(
      <template>
        {{this.tags}}
        <DMenus />
      </template>
    );

    assert
      .dom(".discourse-boards-topic-pill--multiple")
      .hasAria("expanded", "false");

    await click(".discourse-boards-topic-pill--multiple");

    assert
      .dom(".discourse-boards-topic-pill--multiple")
      .hasAria("expanded", "true");
    assert.deepEqual(
      [
        ...document.querySelectorAll(
          ".discourse-boards-boards-menu__item-label"
        ),
      ].map((el) => el.textContent.trim()),
      ["Sales", "Support"]
    );
  });
});
