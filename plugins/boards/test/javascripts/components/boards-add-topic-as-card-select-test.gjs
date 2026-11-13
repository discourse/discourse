import {
  click,
  fillIn,
  findAll,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ModalContainer from "discourse/components/modal-container";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import BoardsAddTopicAsCard from "discourse/plugins/boards/discourse/components/modal/boards-add-topic-as-card";

const MODAL = ".discourse-boards-add-topic-as-card-modal";
const SEARCH = `${MODAL} .d-select [role='combobox']`;
const ADD = `${MODAL} .d-modal__footer .btn-primary`;

const TOPICS = [
  {
    id: 101,
    title: "Rocket launch checklist",
    fancy_title: "Rocket launch checklist",
  },
  {
    id: 202,
    title: "Payload integration notes",
    fancy_title: "Payload integration notes",
  },
  { id: 280, title: "Some topic", fancy_title: "Some topic" },
];

/** The titles of the listed topics, in order. */
function optionTitles() {
  return findAll(`${MODAL} [role='option'] .d-topic-option__title`).map(
    (title) => title.textContent.trim()
  );
}

module(
  "Integration | Component | BoardsAddTopicAsCard | new select controls",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      this.siteSettings.enable_new_select_controls = true;
      this.searches = [];
      pretender.get("/search/query", (request) => {
        const term = request.queryParams.term.trim();
        this.searches.push(request.queryParams);
        // The server resolves a pasted topic URL or path to its topic.
        const byUrl = TOPICS.find((topic) => term.endsWith(`/${topic.id}`));
        const found = byUrl
          ? [byUrl]
          : TOPICS.filter((topic) =>
              topic.title.toLowerCase().includes(term.toLowerCase())
            );
        return response({
          topics: found,
          posts: found.map((topic) => ({
            id: topic.id * 10,
            topic_id: topic.id,
          })),
        });
      });

      this.onAddTopicAsCard = sinon.spy();
      await render(<template><ModalContainer /></template>);
      this.owner.lookup("service:modal").show(BoardsAddTopicAsCard, {
        model: { onAddTopicAsCard: this.onAddTopicAsCard },
      });
      await settled();
    });

    test("searches every topic by title, URL or id", async function (assert) {
      await fillIn(SEARCH, "rocket");

      assert.deepEqual(this.searches, [
        { term: "rocket ", type_filter: "topic", search_for_id: "true" },
      ]);
      assert.deepEqual(optionTitles(), ["Rocket launch checklist"]);
    });

    test("pressing a topic holds it, and the button adds it as a card", async function (assert) {
      await fillIn(SEARCH, "notes");
      await click(`${MODAL} [role='option']`);

      assert.false(this.onAddTopicAsCard.called, "picking alone adds nothing");
      assert.dom(MODAL).exists("the modal stays open");
      assert
        .dom(`${MODAL} .d-select`)
        .hasAttribute(
          "data-name",
          "Payload integration notes",
          "the field holds the topic"
        );

      await click(ADD);
      assert.deepEqual(this.onAddTopicAsCard.firstCall.args[0], {
        topicId: 202,
        title: "Payload integration notes",
      });
      assert.dom(MODAL).doesNotExist("the modal closes behind it");
    });

    test("Enter picks the active topic", async function (assert) {
      await fillIn(SEARCH, "o");
      await triggerKeyEvent(SEARCH, "keydown", "ArrowDown");
      await triggerKeyEvent(SEARCH, "keydown", "Enter");
      await click(ADD);

      assert.true(
        this.onAddTopicAsCard.calledOnce,
        "exactly one topic is added"
      );
      assert.strictEqual(
        this.onAddTopicAsCard.firstCall.args[0].topicId,
        202,
        "the second match, which one press down reached"
      );
    });

    test("the add button waits for a held topic", async function (assert) {
      assert.dom(ADD).isDisabled("nothing is held yet");

      await fillIn(SEARCH, "rocket");
      await click(`${MODAL} [role='option']`);
      assert.dom(ADD).isEnabled("a topic is held");

      await click(`${MODAL} .d-select__clear`);
      assert.dom(ADD).isDisabled("the topic was cleared");
    });

    test("labels the field, without marking it optional", async function (assert) {
      const combobox = document.querySelector(SEARCH);
      assert
        .dom(`${MODAL} label[for='${combobox.id}']`)
        .hasText(i18n("boards.board.topic_search_placeholder"));
      assert.dom(`${MODAL} .form-kit__container-optional`).doesNotExist();
    });

    test("a pasted topic URL or path lists its topic", async function (assert) {
      await fillIn(SEARCH, `${DiscourseURL.origin}/t/some-topic/280`);
      assert.deepEqual(optionTitles(), ["Some topic"], "a full URL");

      await fillIn(SEARCH, "/t/some-topic/280");
      assert.deepEqual(optionTitles(), ["Some topic"], "a path on this site");

      await triggerKeyEvent(SEARCH, "keydown", "Enter");
      await click(ADD);
      assert.strictEqual(this.onAddTopicAsCard.firstCall.args[0].topicId, 280);
    });

    test("Escape closes the results before it closes the modal", async function (assert) {
      await fillIn(SEARCH, "rocket");
      await triggerKeyEvent(SEARCH, "keydown", "Escape");

      assert.dom(`${MODAL} [role='listbox']`).doesNotExist("the results close");
      assert.dom(MODAL).exists("the modal stays open");

      await triggerKeyEvent(SEARCH, "keydown", "Escape");
      assert
        .dom(MODAL)
        .doesNotExist("closed results leave Escape to the modal");
    });

    test("searches from a field, not a list that resizes the modal", async function (assert) {
      assert.dom(`${MODAL} .d-select.--list`).doesNotExist();
      assert.dom(SEARCH).exists();
    });

    test("offers the topics as a single choice", async function (assert) {
      await fillIn(SEARCH, "o");

      assert
        .dom(`${MODAL} [role='listbox']`)
        .doesNotHaveAttribute("aria-multiselectable");
      assert
        .dom(`${MODAL} [role='option'] input[type='checkbox']`)
        .doesNotExist();
    });
  }
);
