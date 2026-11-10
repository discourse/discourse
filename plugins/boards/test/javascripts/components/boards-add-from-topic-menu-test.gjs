import {
  click,
  findAll,
  render,
  settled,
  waitUntil,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import BoardsAddFromTopicColumnSubmenu from "discourse/plugins/boards/discourse/components/boards-add-from-topic-column-submenu";
import BoardsAddFromTopicMenu from "discourse/plugins/boards/discourse/components/boards-add-from-topic-menu";
import Board from "discourse/plugins/boards/discourse/models/board";

function board(id, name, columns, topicIsMember = false) {
  return {
    id,
    name,
    unicode_name: name,
    topic_is_member: topicIsMember,
    columns: columns.map(
      ({ id: columnId, title, icon, color, topic_is_member }) => ({
        id: columnId,
        title,
        unicode_title: title,
        icon,
        color,
        topic_is_member,
        cards: [],
      })
    ),
  };
}

module("Integration | Component | BoardsAddFromTopicMenu", function (hooks) {
  setupRenderingTest(hooks);

  test("shows skeleton rows while boards load", async function (assert) {
    let resolveBoards;
    const boardsResponse = new Promise((resolve) => {
      resolveBoards = resolve;
    });

    pretender.get("/boards/api/boards/available", async () => {
      await boardsResponse;
      return response({
        boards: [board(1, "Roadmap", [{ id: 11, title: "Next" }])],
      });
    });

    this.set("data", { topic: { id: 1 } });

    const renderPromise = render(
      <template><BoardsAddFromTopicMenu @data={{this.data}} /></template>
    );
    await waitUntil(() =>
      document.querySelector(".discourse-boards-add-from-topic-menu__skeleton")
    );

    assert
      .dom(".discourse-boards-add-from-topic-menu__skeleton")
      .exists({ count: 3 });
    assert.dom(".discourse-boards-add-from-topic-menu__board").doesNotExist();

    resolveBoards();
    await renderPromise;
    await settled();

    assert
      .dom(".discourse-boards-add-from-topic-menu__skeleton")
      .doesNotExist();
    assert
      .dom(".discourse-boards-add-from-topic-menu__board")
      .hasText("Roadmap");
  });

  test("only lists boards that have columns", async function (assert) {
    pretender.get("/boards/api/boards/available", () =>
      response({
        boards: [
          board(1, "Roadmap", [{ id: 11, title: "Next" }]),
          board(2, "Empty board", []),
        ],
      })
    );

    this.set("data", { topic: { id: 1 } });

    await render(
      <template><BoardsAddFromTopicMenu @data={{this.data}} /></template>
    );

    assert
      .dom(".discourse-boards-add-from-topic-menu__board")
      .hasText("Roadmap");
    assert
      .dom(".discourse-boards-add-from-topic-menu__board")
      .exists({ count: 1 });
    assert
      .dom(".discourse-boards-add-from-topic-menu__board")
      .doesNotContainText("Empty board");
    assert.deepEqual(
      findAll(".dropdown-menu__subheader").map((element) =>
        element.textContent.trim()
      ),
      ["Add to board"],
      "does not render an empty Already added section"
    );
  });

  test("groups boards by topic membership", async function (assert) {
    pretender.get("/boards/api/boards/available", () =>
      response({
        boards: [
          board(1, "Already on", [{ id: 11, title: "Doing" }], true),
          board(2, "Available", [{ id: 21, title: "Next" }]),
        ],
      })
    );

    this.set("data", { topic: { id: 1 } });

    await render(
      <template><BoardsAddFromTopicMenu @data={{this.data}} /></template>
    );

    assert.deepEqual(
      findAll(".dropdown-menu__subheader").map((element) =>
        element.textContent.trim()
      ),
      ["Add to board", "Already added"]
    );
    assert.deepEqual(
      findAll(".discourse-boards-add-from-topic-menu__board").map((element) =>
        element.textContent.trim()
      ),
      ["Available", "Already on"]
    );
    assert
      .dom(".discourse-boards-add-from-topic-menu .d-icon-circle")
      .doesNotExist();
  });

  test("groups columns by topic membership", async function (assert) {
    this.set("data", {
      board: Board.create(
        board(1, "Roadmap", [
          {
            id: 11,
            title: "Done",
            icon: "check",
            color: "669DF1",
            topic_is_member: true,
          },
          { id: 12, title: "Next", icon: "clock", color: "FCA700" },
        ])
      ),
      topic: { id: 1 },
    });

    await render(
      <template>
        <BoardsAddFromTopicColumnSubmenu @data={{this.data}} />
      </template>
    );

    assert.deepEqual(
      findAll(".dropdown-menu__subheader").map((element) =>
        element.textContent.trim()
      ),
      ["Roadmap", "Already added"]
    );
    const [availableColumn, alreadyAddedColumn] = findAll(
      ".discourse-boards-add-from-topic-column-menu__column"
    );
    assert.deepEqual(
      [availableColumn, alreadyAddedColumn].map((element) =>
        element.textContent.trim()
      ),
      ["Next", "Done"]
    );
    assert
      .dom(".discourse-boards-add-from-topic-column-menu__column .d-icon-clock")
      .exists();
    assert
      .dom(".discourse-boards-add-from-topic-column-menu__column .d-icon-check")
      .exists();
    assert
      .dom(".discourse-boards-add-from-topic-column-menu__column .d-icon-clock")
      .hasStyle({ color: "rgb(252, 167, 0)" });
    assert
      .dom(".discourse-boards-add-from-topic-column-menu__column .d-icon-check")
      .hasStyle({ color: "rgb(102, 157, 241)" });
    assert.dom(".d-button__suffix-icon", availableColumn).doesNotExist();
    assert.dom(".d-button__suffix-icon", alreadyAddedColumn).exists();

    this.set("data", {
      board: Board.create(
        board(1, "Roadmap", [{ id: 12, title: "Next", icon: "clock" }])
      ),
      topic: { id: 1 },
    });
    await settled();

    assert.deepEqual(
      findAll(".dropdown-menu__subheader").map((element) =>
        element.textContent.trim()
      ),
      ["Roadmap"],
      "does not render an empty Already added section"
    );
  });

  test("does not add the topic when the constraint check fails", async function (assert) {
    let addRequests = 0;

    pretender.put("/boards/api/boards/1/check-constraint-mismatches", () =>
      response(500, { errors: ["Constraint check failed"] })
    );
    pretender.post("/boards/api/boards/1/cards", () => {
      addRequests++;
      return response({});
    });

    this.set("data", {
      board: Board.create(
        board(1, "Roadmap", [{ id: 11, title: "Next", icon: "clock" }])
      ),
      topic: { id: 1 },
    });

    await render(
      <template>
        <BoardsAddFromTopicColumnSubmenu @data={{this.data}} />
      </template>
    );
    await click(".discourse-boards-add-from-topic-column-menu__column");

    assert.strictEqual(addRequests, 0);
  });
});
