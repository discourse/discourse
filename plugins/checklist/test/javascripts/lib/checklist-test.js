import {
  click,
  settled,
  triggerKeyEvent,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import { Promise } from "rsvp";
import { consumeOptimisticPostUpdate } from "discourse/lib/optimistic-post-updates";
import { cook } from "discourse/lib/text";
import Post from "discourse/models/post";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { checklistSyntax } from "discourse/plugins/checklist/discourse/initializers/checklist";

let decoratorCleanup;
let holdRequest;
let hydrationRequests;
let initialRaw;
let postModel;
let releaseRequest;
let requests;
let retryableConflicts;
let respondWithError;
let responseRevised;
let responseSequence;

function nextUpdatedAt() {
  responseSequence += 1;
  return `2026-08-27T08:00:0${responseSequence}.000Z`;
}

async function prepare(raw, { canEdit = true, includeRaw = true } = {}) {
  initialRaw = raw;
  const cooked = await cook(raw, {
    siteSettings: {
      checklist_enabled: true,
      discourse_local_dates_enabled: true,
    },
  });

  postModel = Post.create({
    id: 42,
    can_edit: canEdit,
    cooked: cooked.toString(),
    raw: includeRaw ? raw : undefined,
    updated_at: "2026-08-27T08:00:00.000Z",
  });
  const decoratorHelper = { getModel: () => postModel };
  const element = document.createElement("div");
  element.innerHTML = cooked.toString();
  decoratorCleanup = checklistSyntax(element, decoratorHelper);
  document.querySelector("#ember-testing").append(element);

  return [...element.querySelectorAll(".chcklst-box")];
}

acceptance("checklist", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/posts/42", () => {
      hydrationRequests += 1;
      return helper.response({
        id: 42,
        raw: initialRaw,
        updated_at: "2026-08-27T08:00:00.000Z",
      });
    });

    server.put("/checklist/toggle", (request) => {
      const body = JSON.parse(request.requestBody);
      requests.push(body);

      if (retryableConflicts.length > 0) {
        return helper.response(409, {
          errors: ["The post changed"],
          raw: "server conflict raw",
          retryable: true,
          updated_at: retryableConflicts.shift(),
        });
      }

      if (respondWithError) {
        return helper.response(422, {});
      }

      const updatedAt = nextUpdatedAt();
      const response = {
        cooked: `authoritative cooked ${responseSequence}`,
        last_editor_id: 1,
        raw: `authoritative raw ${responseSequence}`,
        revised: responseRevised,
        updated_at: updatedAt,
        version: responseSequence + 1,
      };
      if (responseRevised) {
        consumeOptimisticPostUpdate(body.mutation_id);
      }
      if (holdRequest) {
        return new Promise((resolve) => {
          releaseRequest = () => resolve(helper.response(response));
        });
      }

      return helper.response(response);
    });
  });

  needs.hooks.beforeEach(function () {
    decoratorCleanup = null;
    holdRequest = false;
    hydrationRequests = 0;
    initialRaw = null;
    postModel = null;
    releaseRequest = null;
    requests = [];
    retryableConflicts = [];
    respondWithError = false;
    responseRevised = true;
    responseSequence = 0;
  });

  needs.hooks.afterEach(function () {
    decoratorCleanup?.();
    releaseRequest?.();
    document.querySelector("#ember-testing").innerHTML = "";
  });

  test("sends the direct source location without a redundant count", async function (assert) {
    const boxes = await prepare(`
\`[x]\`
*[x]*
**[x]**
_[x]_
__[x]__
~~[x]~~

[code]
[x]
[ ]
[/code]

Actual checkboxes:
[] first
[x] second
* test[x]*third*
[x] fourth
[x] fifth
    `);

    assert.strictEqual(boxes.length, 5, "only rendered checkboxes are counted");

    await click(boxes[3]);

    assert.true(
      /^[0-9a-f-]{36}$/.test(requests[0].mutation_id),
      "the mutation gets a one-time identifier"
    );
    assert.deepEqual(
      requests[0],
      {
        post_id: 42,
        toggles: [
          {
            checkbox_index: 3,
            checkbox_source: boxes[3].dataset.chkSrc,
            checked: false,
          },
        ],
        expected_raw: initialRaw,
        expected_updated_at: "2026-08-27T08:00:00.000Z",
        mutation_id: requests[0].mutation_id,
      },
      "the server receives the checkbox's rendered position and desired state"
    );
  });

  test("defers authoritative cooked content until teardown", async function (assert) {
    const [checkbox] = await prepare("[ ] first");
    const initialCooked = postModel.cooked;

    await click(checkbox);

    assert.strictEqual(
      postModel.last_editor_id,
      1,
      "last editor metadata is reconciled"
    );
    assert.strictEqual(postModel.version, 2, "version metadata is reconciled");
    assert.strictEqual(
      postModel.raw,
      "authoritative raw 1",
      "raw content is reconciled"
    );
    assert.strictEqual(
      postModel.cooked,
      initialCooked,
      "the visible cooked subtree is not rerendered"
    );
    assert.true(checkbox.isConnected, "the decorated control stays connected");

    decoratorCleanup();
    decoratorCleanup = null;
    await settled();
    assert.strictEqual(
      postModel.cooked,
      "authoritative cooked 1",
      "cooked content is stored for the next render"
    );
  });

  test("does not apply a response older than the loaded post", async function (assert) {
    holdRequest = true;
    const [checkbox] = await prepare("[ ] first");

    checkbox.click();
    await waitUntil(() => releaseRequest);
    postModel.updated_at = "2026-08-27T08:00:09.000Z";
    postModel.raw = "newer raw";
    postModel.cooked = "newer cooked";
    releaseRequest();
    releaseRequest = null;
    await settled();

    assert.strictEqual(postModel.raw, "newer raw", "raw does not regress");
    assert.strictEqual(
      postModel.cooked,
      "newer cooked",
      "cooked does not regress"
    );
    assert.strictEqual(
      postModel.updated_at,
      "2026-08-27T08:00:09.000Z",
      "the timestamp does not regress"
    );
  });

  test("hydrates raw before the first stream toggle", async function (assert) {
    const [checkbox] = await prepare("[ ] first", { includeRaw: false });

    await click(checkbox);

    assert.strictEqual(hydrationRequests, 1, "the missing raw is fetched once");
    assert.strictEqual(
      requests[0].expected_raw,
      "[ ] first",
      "the toggle uses the hydrated baseline"
    );
  });

  test("sends the checkbox count for legacy cooked HTML", async function (assert) {
    const [checkbox] = await prepare("[ ] first\n[ ] second");
    delete checkbox.dataset.chkSrc;

    await click(checkbox);

    assert.strictEqual(
      requests[0].toggles[0].checkbox_count,
      2,
      "index lookup includes the rendered count"
    );
  });

  test("unregisters optimistic tokens when no revision was needed", async function (assert) {
    responseRevised = false;
    const [checkbox] = await prepare("[ ] first");

    await click(checkbox);

    assert.false(
      consumeOptimisticPostUpdate(requests[0].mutation_id),
      "a no-op response leaves no pending token"
    );
  });

  test("updates instantly without hiding or locking the checklist", async function (assert) {
    holdRequest = true;
    const [first, second] = await prepare("[ ] first\n[x] second");

    assert
      .dom(".checklist-spinner")
      .doesNotExist("spinners are created lazily");
    first.click();
    await waitUntil(() => requests.length === 1);

    assert.dom(first).hasClass("checked", "the checkbox changes immediately");
    assert
      .dom(first)
      .hasAttribute("aria-checked", "true", "ARIA state changes immediately");
    assert
      .dom(first)
      .hasAttribute(
        "aria-busy",
        "true",
        "only the pending item is marked busy"
      );
    assert
      .dom(first)
      .hasAttribute(
        "aria-disabled",
        "true",
        "the pending item ignores additional activation"
      );
    assert.dom(first).isVisible("the pending checkbox keeps its layout");
    assert
      .dom(".checklist-spinner", first)
      .isVisible("the familiar spinner is shown immediately");
    assert.strictEqual(
      getComputedStyle(first.querySelector(".checklist-spinner")).animationName,
      "rotate-forever",
      "the pending icon spins in place"
    );
    assert
      .dom(second)
      .doesNotHaveClass("readonly", "other checkboxes remain interactive");

    releaseRequest();
    await settled();

    assert
      .dom(first)
      .doesNotHaveAttribute("aria-busy", "pending state clears after saving");
    assert
      .dom(first)
      .hasClass("checked", "the optimistic state remains after saving");
  });

  test("shows every spinner for at least 200ms", async function (assert) {
    const [checkbox] = await prepare("[ ] first");
    const startedAt = performance.now();

    checkbox.click();
    await waitUntil(() => requests.length === 1);
    await waitUntil(() => !checkbox.hasAttribute("aria-busy"));

    assert
      .dom(checkbox)
      .doesNotHaveAttribute(
        "aria-busy",
        "the semantic busy state follows the completed request"
      );
    assert
      .dom(checkbox)
      .hasAttribute(
        "aria-disabled",
        "true",
        "the control stays inactive while its spinner is visible"
      );
    assert
      .dom(".checklist-spinner", checkbox)
      .isVisible("a quick response still shows the spinner");

    await waitUntil(() => !checkbox.classList.contains("is-saving"));

    assert.true(
      performance.now() - startedAt >= 190,
      "the spinner remains visible for approximately 200ms"
    );
    assert
      .dom(".checklist-spinner", checkbox)
      .isNotVisible("the spinner clears after its minimum display time");
    assert
      .dom(checkbox)
      .doesNotHaveAttribute(
        "aria-disabled",
        "the control is interactive again after the spinner clears"
      );
  });

  test("ignores repeat activation while the spinner is visible", async function (assert) {
    const [checkbox] = await prepare("[ ] first");

    checkbox.click();
    await waitUntil(() => requests.length === 1);
    await waitUntil(() => !checkbox.hasAttribute("aria-busy"));

    checkbox.click();

    assert.strictEqual(requests.length, 1, "the extra click sends no request");
    assert
      .dom(checkbox)
      .hasClass("checked", "the optimistic state is unchanged");

    await waitUntil(() => !checkbox.classList.contains("is-saving"));
    checkbox.click();
    await waitUntil(() => requests.length === 2);

    assert.deepEqual(
      requests.flatMap((request) =>
        request.toggles.map((toggle) => toggle.checked)
      ),
      [true, false],
      "the checkbox accepts input again after the spinner clears"
    );
  });

  test("waits for the active request before sending another checkbox", async function (assert) {
    holdRequest = true;
    const [first, second, third] = await prepare(
      "[ ] first\n[ ] second\n[ ] third"
    );

    first.click();
    await waitUntil(() => releaseRequest);
    second.click();
    third.click();

    assert.dom(first).hasClass("checked", "the first change is optimistic");
    assert.dom(second).hasClass("checked", "the second change is optimistic");
    assert.dom(third).hasClass("checked", "the third change is optimistic");
    assert
      .dom(first)
      .hasAttribute(
        "aria-busy",
        "true",
        "the first item remains busy until its request completes"
      );
    assert.strictEqual(
      requests.length,
      1,
      "the second request waits for the first response"
    );

    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await waitUntil(() => requests.length === 2);

    assert.deepEqual(
      requests.map((request) =>
        request.toggles.map((toggle) => toggle.checkbox_index)
      ),
      [[0], [1, 2]],
      "the first change is immediate and the backlog is one batch"
    );
    assert.strictEqual(
      requests[1].expected_raw,
      "authoritative raw 1",
      "the second request uses the first response's raw"
    );
    assert.strictEqual(
      requests[1].expected_updated_at,
      "2026-08-27T08:00:01.000Z",
      "the second request uses the first response's revision token"
    );
  });

  test("stops queued work after the decorated content is destroyed", async function (assert) {
    holdRequest = true;
    const [first, second] = await prepare("[ ] first\n[ ] second");

    first.click();
    second.click();
    await waitUntil(() => requests.length === 1);
    decoratorCleanup();
    assert.false(
      consumeOptimisticPostUpdate(requests[0].mutation_id),
      "the detached decoration unregisters its in-flight mutation"
    );
    releaseRequest();
    await settled();

    assert.strictEqual(
      requests.length,
      1,
      "detached controls do not send stale queued changes"
    );
    assert.strictEqual(
      postModel.raw,
      "authoritative raw 1",
      "the detached model retains the confirmed raw content"
    );
    assert.strictEqual(
      postModel.cooked,
      "authoritative cooked 1",
      "the detached model retains the confirmed cooked content"
    );
  });

  test("recovers a stale request without discarding its backlog", async function (assert) {
    retryableConflicts = ["2026-08-27T08:00:10.000Z"];
    const [first, second, third] = await prepare(
      "[ ] first\n[ ] second\n[ ] third"
    );

    first.click();
    second.click();
    third.click();
    await waitUntil(() => requests.length === 3);
    await waitUntil(() =>
      [first, second, third].every(
        (checkbox) => !checkbox.classList.contains("is-saving")
      )
    );

    assert.deepEqual(
      requests.map((request) =>
        request.toggles.map((toggle) => toggle.checkbox_index)
      ),
      [[0], [0], [1, 2]],
      "the failed batch is retried before the accumulated backlog"
    );
    assert.strictEqual(
      requests[1].expected_raw,
      "server conflict raw",
      "the retry uses the server's authoritative raw"
    );
    assert.strictEqual(
      requests[1].expected_updated_at,
      "2026-08-27T08:00:10.000Z",
      "the retry uses the server's authoritative timestamp"
    );
    assert.notStrictEqual(
      requests[1].mutation_id,
      requests[0].mutation_id,
      "the retry receives a new reconciliation token"
    );
    assert
      .dom(first)
      .hasClass("checked", "the retried optimistic state is retained");
    assert.dom(second).hasClass("checked", "the backlog is retained");
    assert.dom(third).hasClass("checked", "the backlog remains batched");
    assert
      .dom(first)
      .doesNotHaveAttribute(
        "aria-busy",
        "the recovered save completes normally"
      );
  });

  test("reverts an unconfirmed optimistic change on error", async function (assert) {
    respondWithError = true;
    const [checkbox] = await prepare("[ ] first");

    await click(checkbox);

    assert
      .dom(checkbox)
      .doesNotHaveClass("checked", "the server-confirmed state is restored");
    assert
      .dom(checkbox)
      .doesNotHaveAttribute("aria-busy", "pending state is cleared");
  });

  test("supports keyboard interaction and exposes checkbox semantics", async function (assert) {
    const [checkbox] = await prepare("[ ] Buy milk");

    assert
      .dom(checkbox)
      .hasAttribute("role", "checkbox", "the control exposes its role");
    assert
      .dom(checkbox)
      .hasAttribute("tabindex", "0", "the control is keyboard focusable");
    assert
      .dom(checkbox)
      .hasAttribute("aria-label", "Buy milk", "the task labels the control");

    await triggerKeyEvent(checkbox, "keydown", " ");
    assert
      .dom(checkbox)
      .hasAttribute("aria-checked", "true", "Space checks the item");

    await waitUntil(() => !checkbox.classList.contains("is-saving"));
    await triggerKeyEvent(checkbox, "keydown", "Enter");
    assert
      .dom(checkbox)
      .hasAttribute("aria-checked", "false", "Enter unchecks the item");
  });

  test("labels multiple controls from their own task text", async function (assert) {
    const [first, second] = await prepare("[ ] Buy milk [ ] Wash car");

    assert
      .dom(first)
      .hasAttribute(
        "aria-label",
        "Buy milk",
        "the first task has its own label"
      );
    assert
      .dom(second)
      .hasAttribute(
        "aria-label",
        "Wash car",
        "the second task has its own label"
      );
  });

  test("uses a fallback label for an empty checklist item", async function (assert) {
    const [checkbox] = await prepare("- [ ]");

    assert
      .dom(checkbox)
      .hasAttribute("aria-label", "Checklist item", "the empty item is named");
  });

  test("does not make quoted checkboxes interactive", async function (assert) {
    const [quoted, own] = await prepare(
      '[quote="Other user"]\n[ ] quoted task\n[/quote]\n\n[ ] own task'
    );

    assert
      .dom(quoted)
      .hasAttribute(
        "aria-readonly",
        "true",
        "the quoted checkbox is read-only"
      );
    assert.dom(quoted).doesNotHaveAttribute("tabindex");
    await click(quoted);
    assert.strictEqual(requests.length, 0, "the quote sends no request");

    await click(own);
    assert.strictEqual(requests.length, 1, "the post's own checkbox toggles");
    assert.strictEqual(
      requests[0].toggles[0].checkbox_index,
      0,
      "quoted checkboxes are excluded from the rendered index"
    );
  });

  test("permanent and read-only checkboxes are not interactive", async function (assert) {
    const [permanent] = await prepare("[X] permanent");

    assert
      .dom(permanent)
      .hasAttribute("aria-disabled", "true", "permanent items are disabled");
    assert
      .dom(permanent)
      .doesNotHaveAttribute("tabindex", "permanent items are not focusable");
    await click(permanent);
    assert.strictEqual(requests.length, 0, "permanent items do not save");

    document.querySelector("#ember-testing").innerHTML = "";
    const [readOnly] = await prepare("[x] completed", { canEdit: false });

    assert
      .dom(readOnly)
      .hasAttribute(
        "aria-readonly",
        "true",
        "non-editors get a read-only state"
      );
    assert
      .dom(readOnly)
      .doesNotHaveAttribute("tabindex", "read-only items are not focusable");
    await click(readOnly);
    assert.strictEqual(requests.length, 0, "read-only items do not save");
  });

  test("preserves checklist list styling", async function (assert) {
    await prepare(`
- [ ] LI 1
- LI 2 [ ] with checkbox in middle
- [ ] LI 3

1. [ ] Ordered LI with checkbox
    `);

    const listItems = [...document.querySelectorAll("ul > li")];
    assert
      .dom(listItems[0])
      .hasClass("has-checkbox", "a leading checkbox removes the bullet");
    assert
      .dom(listItems[1])
      .doesNotHaveClass("has-checkbox", "an inline checkbox keeps the bullet");
    assert
      .dom(listItems[2])
      .hasClass("has-checkbox", "another leading checkbox removes the bullet");
    assert
      .dom("ol > li")
      .doesNotHaveClass("has-checkbox", "ordered lists keep their numbering");
  });
});
