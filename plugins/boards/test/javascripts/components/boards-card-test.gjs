import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BoardsCard from "discourse/plugins/boards/discourse/components/boards-card";
import BoardsFabricators from "discourse/plugins/boards/discourse/lib/fabricators";

module("Integration | Component | BoardsCard", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new BoardsFabricators(getOwner(this));
    this.card = this.fabricators.card();
    this.board = this.fabricators.board();
    this.card.board_id = this.board.id;
  });

  test("renders basic card", async function (assert) {
    await render(
      <template>
        <BoardsCard @card={{this.card}} @board={{this.board}} />
      </template>
    );
    assert.dom(".discourse-boards-card").exists();
    assert.dom(".discourse-boards-card__title").hasText(this.card.title);
  });

  test("renders a floater card's Unicode title", async function (assert) {
    this.card.title = "Launch :rocket:";
    this.card.unicode_title = "Launch 🚀";

    await render(
      <template>
        <BoardsCard @card={{this.card}} @board={{this.board}} />
      </template>
    );

    assert.dom(".discourse-boards-card__title").hasText("Launch 🚀");
  });

  test("renders stored inline onebox data for a floater card", async function (assert) {
    this.card.title = "https://github.com/discourse/discourse/pull/42462";
    this.card.inline_onebox_data = {
      url: this.card.title,
      title: "FEATURE: Add ProseMirror tab support",
      css_class: "--gh-status-approved",
    };

    await render(
      <template>
        <BoardsCard @card={{this.card}} @board={{this.board}} />
      </template>
    );

    assert
      .dom(".discourse-boards-card__title a.inline-onebox")
      .hasAttribute("href", this.card.title)
      .hasAttribute("target", "_blank")
      .hasClass("--gh-status-approved")
      .hasText("FEATURE: Add ProseMirror tab support");
  });

  test("renders a topic card's Unicode title", async function (assert) {
    this.card = this.fabricators.card({
      topic: {
        id: 42,
        title: "Topic :rocket:",
        unicode_title: "Topic 🚀",
      },
    });

    await render(
      <template>
        <BoardsCard @card={{this.card}} @board={{this.board}} />
      </template>
    );

    assert
      .dom(".discourse-boards-card__title.discourse-boards-card__title--topic")
      .hasText("Topic");
    assert
      .dom('.discourse-boards-card__title--topic img.emoji[title="rocket"]')
      .exists();
  });

  test("unescapes emoji shortcodes remaining in a topic card's Unicode title", async function (assert) {
    this.card = this.fabricators.card({
      topic: {
        id: 42,
        title: "Funny topic :joy:",
        unicode_title: "Funny topic :joy:",
      },
    });

    await render(
      <template>
        <BoardsCard @card={{this.card}} @board={{this.board}} />
      </template>
    );

    assert
      .dom('.discourse-boards-card__title--topic img.emoji[title="joy"]')
      .exists();
  });

  test("escapes topic card titles before unescaping emoji", async function (assert) {
    this.card = this.fabricators.card({
      topic: {
        id: 42,
        title: '<img src=x data-dangerous="true"> :joy:',
      },
    });

    await render(
      <template>
        <BoardsCard @card={{this.card}} @board={{this.board}} />
      </template>
    );

    assert.dom('[data-dangerous="true"]').doesNotExist();
    assert
      .dom('.discourse-boards-card__title--topic img.emoji[title="joy"]')
      .exists();
    assert
      .dom(".discourse-boards-card__title--topic")
      .includesText('<img src=x data-dangerous="true">');
  });

  test("suppresses column tags on floater cards", async function (assert) {
    this.card.tags = [
      { id: 1, name: "todo", slug: "todo" },
      { id: 2, name: "unrelated", slug: "unrelated" },
    ];
    this.columnTags = ["todo"];

    await render(
      <template>
        <BoardsCard
          @card={{this.card}}
          @board={{this.board}}
          @columnTags={{this.columnTags}}
        />
      </template>
    );

    assert.dom(".discourse-boards-card__tags").hasText("unrelated");
    assert.dom(".discourse-boards-card__tags").doesNotContainText("todo");
  });
});

module(
  "Integration | Component | BoardsCard | Discourse Assign",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.fabricators = new BoardsFabricators(getOwner(this));
      this.card = this.fabricators.card();
      this.board = this.fabricators.board();
      this.board.card_style = "detailed";
      this.card.board_id = this.board.id;
      this.currentUser.can_assign = true;
      this.siteSettings.assign_enabled = true;
    });

    test("does not render assign button when assign_enabled is false", async function (assert) {
      this.siteSettings.assign_enabled = false;
      await render(
        <template>
          <BoardsCard
            @card={{this.card}}
            @board={{this.board}}
            @canWrite={{this.board.can_write}}
          />
        </template>
      );
      assert.dom(".discourse-boards-card__assign-btn").doesNotExist();
    });

    test("renders assign button for a floating card", async function (assert) {
      this.card.card_type = "floater";
      await render(
        <template>
          <BoardsCard
            @card={{this.card}}
            @board={{this.board}}
            @canWrite={{this.board.can_write}}
          />
        </template>
      );
      assert.dom(".discourse-boards-card__assign-btn").exists();
    });

    test("renders assign button for a topic card", async function (assert) {
      const topic = this.fabricators.coreFabricators.topic();
      this.card.card_type = "topic";
      this.card.topic_id = topic.id;
      this.card.topic = topic;

      await render(
        <template>
          <BoardsCard
            @card={{this.card}}
            @board={{this.board}}
            @canWrite={{this.board.can_write}}
          />
        </template>
      );
      assert.dom(".discourse-boards-card__assign-btn").exists();
    });

    test("does not render assignment for a closed topic card", async function (assert) {
      const topic = this.fabricators.coreFabricators.topic();
      topic.closed = true;
      this.card.card_type = "topic";
      this.card.topic_id = topic.id;
      this.card.topic = topic;
      topic.closed = true;
      await render(
        <template>
          <BoardsCard
            @card={{this.card}}
            @board={{this.board}}
            @canWrite={{this.board.can_write}}
          />
        </template>
      );
      assert.dom(".discourse-boards-card__assign-btn").doesNotExist();
    });
  }
);
