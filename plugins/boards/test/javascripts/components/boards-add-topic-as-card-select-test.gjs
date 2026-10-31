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
import BoardsAddTopicAsCard from "discourse/plugins/boards/discourse/components/modal/boards-add-topic-as-card";

const MODAL = ".discourse-boards-add-topic-as-card-modal";
const SEARCH = `${MODAL} .d-select.--list input[type='search']`;

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

    test("pressing a topic adds it as a card and closes", async function (assert) {
      await fillIn(SEARCH, "notes");
      await click(`${MODAL} [role='option']`);

      assert.deepEqual(this.onAddTopicAsCard.firstCall.args[0], {
        topicId: 202,
        title: "Payload integration notes",
      });
      assert.dom(MODAL).doesNotExist("the modal closes behind it");
    });

    test("Enter adds the active topic", async function (assert) {
      await fillIn(SEARCH, "o");
      await triggerKeyEvent(SEARCH, "keydown", "ArrowDown");
      await triggerKeyEvent(SEARCH, "keydown", "Enter");

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

    test("a pasted topic URL or path lists its topic", async function (assert) {
      await fillIn(SEARCH, `${DiscourseURL.origin}/t/some-topic/280`);
      assert.deepEqual(optionTitles(), ["Some topic"], "a full URL");

      await fillIn(SEARCH, "/t/some-topic/280");
      assert.deepEqual(optionTitles(), ["Some topic"], "a path on this site");

      await triggerKeyEvent(SEARCH, "keydown", "Enter");
      assert.strictEqual(this.onAddTopicAsCard.firstCall.args[0].topicId, 280);
    });

    test("Escape clears the search before it closes the modal", async function (assert) {
      await fillIn(SEARCH, "rocket");
      await triggerKeyEvent(SEARCH, "keydown", "Escape");

      assert.dom(SEARCH).hasValue("", "the search is cleared");
      assert.dom(MODAL).exists("the modal stays open");

      await triggerKeyEvent(SEARCH, "keydown", "Escape");
      assert
        .dom(MODAL)
        .doesNotExist("an empty search leaves Escape to the modal");
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

    test("needs no submit button, since a pick adds the card", async function (assert) {
      assert.dom(`${MODAL} .d-modal__footer .btn-primary`).doesNotExist();
      assert.dom(`${MODAL} .d-modal__footer .btn-transparent`).exists();
    });
  }
);
