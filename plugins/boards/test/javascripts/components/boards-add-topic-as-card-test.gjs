import {
  click,
  fillIn,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import BoardsAddTopicAsCard from "discourse/plugins/boards/discourse/components/modal/boards-add-topic-as-card";

const MODAL = ".discourse-boards-add-topic-as-card-modal";
const INPUT = "input.topic-search-input";
const RESULTS = ".internal-link-results";
const LINK = ".internal-link-results .search-link";

const TOPICS = [
  {
    id: 101,
    title: "Rocket launch checklist",
    fancy_title: "Rocket launch checklist",
    slug: "rocket-launch-checklist",
  },
  {
    id: 202,
    title: "Payload integration notes",
    fancy_title: "Payload integration notes",
    slug: "payload-integration-notes",
  },
];

/**
 * Types into the search box. `fillIn` settles the runloop, which carries the
 * 400ms debounce and the search request with it, so the results are on screen
 * by the time this returns.
 */
async function search(term) {
  await fillIn(INPUT, term);
}

module("Integration | Component | BoardsAddTopicAsCard", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.searchCount = 0;
    pretender.get("/search/query", () => {
      this.searchCount++;
      return response({ topics: TOPICS });
    });

    this.onAddTopicAsCard = sinon.spy();
    this.closeModal = sinon.spy();
    this.model = { onAddTopicAsCard: this.onAddTopicAsCard };
  });

  test("a term shorter than the minimum searches for nothing", async function (assert) {
    await render(
      <template>
        <BoardsAddTopicAsCard
          @model={{this.model}}
          @closeModal={{this.closeModal}}
          @inline={{true}}
        />
      </template>
    );

    await search("roc");

    assert.strictEqual(this.searchCount, 0, "no search is issued");
    assert.dom(RESULTS).doesNotExist("and nothing is offered");
  });

  test("a long enough term lists the topics it found", async function (assert) {
    await render(
      <template>
        <BoardsAddTopicAsCard
          @model={{this.model}}
          @closeModal={{this.closeModal}}
          @inline={{true}}
        />
      </template>
    );

    await search("rocket");

    assert.strictEqual(this.searchCount, 1, "one search is issued");
    assert.dom(LINK).exists({ count: 2 }, "both topics are offered");
    assert
      .dom(LINK)
      .hasAttribute("data-topic-id", "101", "in the order they came back");
  });

  test("moving down to a result and pressing Enter adds that topic", async function (assert) {
    await render(
      <template>
        <BoardsAddTopicAsCard
          @model={{this.model}}
          @closeModal={{this.closeModal}}
          @inline={{true}}
        />
      </template>
    );

    await search("rocket");
    await triggerKeyEvent(MODAL, "keydown", "ArrowDown");
    await triggerKeyEvent(MODAL, "keydown", "ArrowDown");
    await triggerKeyEvent(MODAL, "keydown", "Enter");

    assert.true(this.onAddTopicAsCard.calledOnce, "exactly one topic is added");
    assert.deepEqual(
      this.onAddTopicAsCard.firstCall.args[0],
      { topicId: 202, title: "Payload integration notes" },
      "and it is the second one, the one two presses reached"
    );
    assert.true(this.closeModal.calledOnce, "the modal closes behind it");
  });

  test("moving back off the results returns Enter to the form", async function (assert) {
    await render(
      <template>
        <BoardsAddTopicAsCard
          @model={{this.model}}
          @closeModal={{this.closeModal}}
          @inline={{true}}
        />
      </template>
    );

    await search("rocket");
    await triggerKeyEvent(MODAL, "keydown", "ArrowDown");
    await triggerKeyEvent(MODAL, "keydown", "ArrowUp");
    await triggerKeyEvent(INPUT, "keydown", "Enter");

    assert.false(
      this.onAddTopicAsCard.called,
      "a plain term submits rather than adding whatever was last highlighted"
    );
    assert.false(this.closeModal.called, "and the modal stays open");
  });

  test("Escape never reaches the search, so the results stay put", async function (assert) {
    await render(
      <template>
        <BoardsAddTopicAsCard
          @model={{this.model}}
          @closeModal={{this.closeModal}}
          @inline={{true}}
        />
      </template>
    );

    await search("rocket");
    assert.dom(LINK).exists({ count: 2 }, "results are showing first");

    await triggerKeyEvent(MODAL, "keydown", "Escape");

    // The modal listens for Escape on the document in the capture phase and
    // stops propagation there, so the search's own Escape branch cannot run.
    // Pinned as it stands; the results are meant to close on Escape.
    assert
      .dom(LINK)
      .exists({ count: 2 }, "the results are still on screen afterwards");
  });

  test("clicking a result adds it", async function (assert) {
    await render(
      <template>
        <BoardsAddTopicAsCard
          @model={{this.model}}
          @closeModal={{this.closeModal}}
          @inline={{true}}
        />
      </template>
    );

    await search("rocket");
    await click(LINK);

    assert.deepEqual(
      this.onAddTopicAsCard.firstCall.args[0],
      { topicId: 101, title: "Rocket launch checklist" },
      "the clicked topic is the one added"
    );
    assert.true(this.closeModal.calledOnce, "and the modal closes");
  });

  test("a modified click is left to the browser to follow", async function (assert) {
    await render(
      <template>
        <BoardsAddTopicAsCard
          @model={{this.model}}
          @closeModal={{this.closeModal}}
          @inline={{true}}
        />
      </template>
    );

    await search("rocket");
    await triggerEvent(LINK, "click", { metaKey: true });

    assert.false(
      this.onAddTopicAsCard.called,
      "meta-click opens the topic rather than adding it as a card"
    );
    assert.false(this.closeModal.called, "and leaves the modal alone");
  });

  test("pressing outside the search puts the results away", async function (assert) {
    await render(
      <template>
        <BoardsAddTopicAsCard
          @model={{this.model}}
          @closeModal={{this.closeModal}}
          @inline={{true}}
        />
      </template>
    );

    await search("rocket");
    assert.dom(LINK).exists({ count: 2 }, "results are showing first");

    await triggerEvent(`${MODAL} .d-modal__footer`, "mousedown");

    assert.dom(RESULTS).doesNotExist("a press elsewhere dismisses them");
  });

  test("submitting a topic URL adds that topic without searching", async function (assert) {
    await render(
      <template>
        <BoardsAddTopicAsCard
          @model={{this.model}}
          @closeModal={{this.closeModal}}
          @inline={{true}}
        />
      </template>
    );

    // Built from the running origin: only a same-origin absolute URL is both
    // recognised as a topic link and skipped by the search.
    await search(`${DiscourseURL.origin}/t/some-topic/280`);
    assert.strictEqual(this.searchCount, 0, "a URL is not a search term");

    await click(`${MODAL} .d-modal__footer .btn-primary`);

    assert.strictEqual(
      this.onAddTopicAsCard.firstCall.args[0].topicId,
      280,
      "the id is read out of the URL"
    );
    assert.true(this.closeModal.calledOnce, "and the modal closes");
  });
});
