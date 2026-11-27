import { findAll, focus, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";
import ChatSearch from "discourse/plugins/chat/discourse/components/chat-search";

const SORT = ".chat-search__sort";

module("Discourse Chat | Component | ChatSearch | sort", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.sorts = [];
    pretender.get("/chat/api/search", (request) => {
      this.sorts.push(request.queryParams.sort);
      return response({ messages: [], meta: { has_more: false } });
    });
  });

  test("keeps today's menu without new select controls", async function (assert) {
    await render(
      <template>
        <ChatSearch @enableQueryParams={{false}} @query="hello" />
      </template>
    );

    assert.dom(".fk-d-menu__trigger.search-sort-options-trigger").exists();
    assert.dom(SORT).doesNotExist();
  });

  module("with new select controls", function (flagHooks) {
    flagHooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("shows the current sort, and is named by what it sorts", async function (assert) {
      await render(
        <template>
          <ChatSearch @enableQueryParams={{false}} @query="hello" />
        </template>
      );

      assert.dSelect(SORT).hasValue("relevance");
      assert
        .dom(SORT)
        .hasAttribute("role", "combobox")
        .hasAria("label", i18n("chat.search.sort_label"))
        .hasText(i18n("chat.search.sort.relevance"));
      assert.dom(`${SORT} .d-icon-arrow-down-wide-short`).exists();
    });

    test("lists both sorts and checks the current one", async function (assert) {
      await render(
        <template>
          <ChatSearch @enableQueryParams={{false}} @query="hello" />
        </template>
      );
      await dSelect(SORT).open();

      assert.dSelect(SORT).hasOptions(["relevance", "latest"]);
      assert.deepEqual(
        findAll("[role='option']").map((row) => row.dataset.name),
        [i18n("chat.search.sort.relevance"), i18n("chat.search.sort.latest")]
      );
      assert.dSelect(SORT).hasSelectedOption("relevance");
    });

    test("searches again with the picked sort", async function (assert) {
      await render(
        <template>
          <ChatSearch @enableQueryParams={{false}} @query="hello" />
        </template>
      );
      await dSelect(SORT).select("latest");

      assert.deepEqual(this.sorts, ["relevance", "latest"]);
      assert.dSelect(SORT).hasValue("latest");
      assert.dom(SORT).hasText(i18n("chat.search.sort.latest"));
    });

    test("keeps the sort when Backspace is pressed on it, and doesn't say it was cleared", async function (assert) {
      const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
      await render(
        <template>
          <ChatSearch @enableQueryParams={{false}} @query="hello" />
        </template>
      );
      await dSelect(SORT).select("latest");
      await focus(SORT);
      await triggerKeyEvent(SORT, "keydown", "Backspace");

      assert.dSelect(SORT).hasValue("latest");
      assert.deepEqual(this.sorts, ["relevance", "latest"]);
      assert.false(
        announce.calledWith(i18n("d_select.selection_cleared")),
        "nothing was cleared"
      );
    });
  });
});
