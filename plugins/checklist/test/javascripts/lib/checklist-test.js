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
import {
  activeChecklistOperationCountForTesting,
  checklistSyntax,
} from "discourse/plugins/checklist/discourse/initializers/checklist";

let decoratorCleanup;
let decoratedElement;
let failHeldRequest;
let holdHydration;
let holdRequest;
let hydrationRequests;
let hydrationResponse;
let initialRaw;
let postModel;
let releaseHydration;
let releaseRequest;
let requests;
let retryableConflicts;
let respondWithError;
let responseRevised;
let responseSequence;
let responseUpdatedAts;
let responseCookeds;

function applyToggleToRaw(raw, toggle) {
  if (toggle.checkbox_source) {
    const [lineNumber, markerNumber] = toggle.checkbox_source
      .split(":")
      .map(Number);
    const lines = raw.split("\n");
    let markerIndex = -1;
    lines[lineNumber] = lines[lineNumber].replace(/\[[ xX]?\]/g, (marker) => {
      markerIndex += 1;
      return markerIndex === markerNumber
        ? toggle.checked
          ? "[x]"
          : "[ ]"
        : marker;
    });
    return lines.join("\n");
  }

  let checkboxIndex = -1;
  return raw.replace(/\[(?: |x)?\]/g, (marker) => {
    checkboxIndex += 1;
    return checkboxIndex === toggle.checkbox_index
      ? toggle.checked
        ? "[x]"
        : "[ ]"
      : marker;
  });
}

function nextUpdatedAt() {
  responseSequence += 1;
  if (responseUpdatedAts.length > 0) {
    return responseUpdatedAts.shift();
  }

  return `2026-08-27T08:00:0${responseSequence}.000Z`;
}

async function decorate(raw, { legacy = false } = {}) {
  const cooked = await cook(raw, {
    siteSettings: {
      checklist_enabled: true,
      discourse_local_dates_enabled: true,
    },
  });
  return decorateCooked(cooked.toString(), { legacy });
}

function decorateCooked(cooked, { legacy = false } = {}) {
  const decoratorHelper = { getModel: () => postModel };
  decoratedElement = document.createElement("div");
  decoratedElement.innerHTML = cooked.toString();
  if (legacy) {
    decoratedElement
      .querySelectorAll(".chcklst-box")
      .forEach((box) => delete box.dataset.chkSrc);
  }
  decoratorCleanup = checklistSyntax(decoratedElement, decoratorHelper);
  document.querySelector("#ember-testing").append(decoratedElement);

  return [...decoratedElement.querySelectorAll(".chcklst-box")];
}

async function prepare(
  raw,
  { canEdit = true, includeRaw = true, legacyCooked = false } = {}
) {
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

  return decorate(raw, { legacy: legacyCooked });
}

acceptance("checklist", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/posts/42", () => {
      hydrationRequests += 1;
      const response = helper.response({
        id: 42,
        raw: hydrationResponse?.raw ?? initialRaw,
        cooked: hydrationResponse?.cooked,
        updated_at: hydrationResponse?.updatedAt ?? "2026-08-27T08:00:00.000Z",
      });
      if (holdHydration) {
        return new Promise((resolve) => {
          releaseHydration = () => resolve(response);
        });
      }
      return response;
    });

    server.put("/checklist/toggle", (request) => {
      const body = JSON.parse(request.requestBody);
      requests.push(body);

      if (retryableConflicts.length > 0) {
        const conflict = retryableConflicts.shift();
        return helper.response(409, {
          errors: ["The post changed"],
          raw:
            typeof conflict === "string" ? "server conflict raw" : conflict.raw,
          retryable:
            typeof conflict === "string" ? true : (conflict.retryable ?? true),
          updated_at:
            typeof conflict === "string" ? conflict : conflict.updatedAt,
        });
      }

      if (respondWithError === "network") {
        request.onerror();
        return helper.response(0, {});
      }
      if (respondWithError) {
        return helper.response(422, {});
      }

      const updatedAt = nextUpdatedAt();
      const raw = body.toggles.reduce(
        (currentRaw, toggle) => applyToggleToRaw(currentRaw, toggle),
        body.expected_raw
      );
      const response = {
        cooked:
          responseCookeds.shift() ?? `authoritative cooked ${responseSequence}`,
        last_editor_id: 1,
        raw,
        revised: responseRevised,
        updated_at: updatedAt,
        version: responseSequence + 1,
      };
      if (responseRevised) {
        consumeOptimisticPostUpdate(body.mutation_id);
      }
      if (holdRequest) {
        return new Promise((resolve) => {
          releaseRequest = () => {
            const shouldError = failHeldRequest;
            failHeldRequest = false;
            resolve(
              shouldError ? helper.response(422, {}) : helper.response(response)
            );
          };
        });
      }

      return helper.response(response);
    });
  });

  needs.hooks.beforeEach(function () {
    decoratorCleanup = null;
    decoratedElement = null;
    failHeldRequest = false;
    holdHydration = false;
    holdRequest = false;
    hydrationRequests = 0;
    hydrationResponse = null;
    initialRaw = null;
    postModel = null;
    releaseHydration = null;
    releaseRequest = null;
    requests = [];
    retryableConflicts = [];
    respondWithError = false;
    responseRevised = true;
    responseSequence = 0;
    responseUpdatedAts = [];
    responseCookeds = [];
  });

  needs.hooks.afterEach(async function (assert) {
    decoratorCleanup?.();
    releaseHydration?.();
    releaseRequest?.();
    await settled();
    assert.strictEqual(
      activeChecklistOperationCountForTesting(),
      0,
      "no coordinator survives test teardown"
    );
    document.querySelector("#ember-testing").innerHTML = "";
  });

  test("adopts pending state after raw-less hydration completes", async function (assert) {
    holdRequest = true;
    const [first, second] = await prepare("[ ] first\n[ ] second", {
      includeRaw: false,
    });
    first.click();
    await waitUntil(() => releaseRequest);
    second.click();
    decoratorCleanup();
    decoratedElement.remove();
    const [replacementFirst, replacementSecond] = decorateCooked(
      postModel.cooked
    );
    assert
      .dom(replacementFirst)
      .hasClass("checked", "in-flight state is adopted after hydration");
    assert
      .dom(replacementSecond)
      .hasClass("checked", "the second click is retained");
    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await settled();
    assert.strictEqual(
      postModel.raw,
      "[x] first\n[x] second",
      "both changes persist"
    );
  });

  test("a late raw-less rendering joins the hydrated queue", async function (assert) {
    holdRequest = true;
    const [first] = await prepare("[ ] first\n[ ] second", {
      includeRaw: false,
    });
    const firstCleanup = decoratorCleanup;
    const [, second] = await decorate("[ ] first\n[ ] second");
    first.click();
    await waitUntil(() => releaseRequest);
    second.click();
    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await settled();
    firstCleanup();
    assert.strictEqual(
      postModel.raw,
      "[x] first\n[x] second",
      "the late rendering shares validated hydration"
    );
  });

  test("an idle raw-less rendering revalidates after the coordinator retires", async function (assert) {
    const [first] = await prepare("[ ] first\n[ ] second", {
      includeRaw: false,
    });
    const firstCleanup = decoratorCleanup;
    const [, second] = await decorate("[ ] first\n[ ] second");
    await click(first);
    hydrationResponse = {
      raw: postModel.raw,
      cooked: (await cook(postModel.raw)).toString(),
      updatedAt: postModel.updated_at,
    };
    await click(second);
    firstCleanup();
    assert.strictEqual(
      postModel.raw,
      "[x] first\n[x] second",
      "old cooked is validated before reusing its coordinates"
    );
  });

  test("hydration merges colliding generations without losing presentations", async function (assert) {
    holdHydration = true;
    const [first] = await prepare("[ ] first", { includeRaw: false });
    const firstCleanup = decoratorCleanup;
    first.click();
    await waitUntil(() => releaseHydration);
    postModel.raw = "[ ] first";
    const [replacement] = await decorate("[ ] first");
    replacement.click();
    replacement.click();
    holdHydration = false;
    releaseHydration();
    releaseHydration = null;
    await settled();
    firstCleanup();
    assert.strictEqual(
      postModel.raw,
      "[ ] first",
      "the newer desired state wins on generation merge"
    );
    assert
      .dom(replacement)
      .doesNotHaveAttribute("aria-busy", "the newer rendering settles");
  });

  test("a failed hydrated generation merge does not resend the rejected change", async function (assert) {
    holdHydration = true;
    respondWithError = true;
    const [first] = await prepare("[ ] first", { includeRaw: false });
    const firstCleanup = decoratorCleanup;
    first.click();
    await waitUntil(() => releaseHydration);
    postModel.raw = "[ ] first";
    const [replacement] = await decorate("[ ] first");
    replacement.click();
    holdHydration = false;
    releaseHydration();
    releaseHydration = null;
    await settled();
    firstCleanup();

    assert.strictEqual(
      requests.length,
      1,
      "a non-retryable failure is not sent twice"
    );
    assert
      .dom(replacement)
      .doesNotHaveAttribute("aria-busy", "the merged rendering settles");
    assert
      .dom(replacement)
      .doesNotHaveClass("checked", "the rejected change is reverted");
  });

  test("uncertain baseline survives cooked replacement without deleting raw", async function (assert) {
    respondWithError = "network";
    const [first] = await prepare("[ ] first");
    await click(first);
    decoratorCleanup();
    decoratedElement.remove();
    const [replacement] = decorateCooked(postModel.cooked);
    respondWithError = false;
    await click(replacement);
    assert.strictEqual(
      hydrationRequests,
      1,
      "the replacement revalidates the uncertain model baseline"
    );
    assert.strictEqual(postModel.raw, "[x] first", "recovered work is saved");
  });

  test("limits coalesced requests to the server batch size", async function (assert) {
    const boxes = await prepare(
      Array.from({ length: 51 }, (_, i) => `[ ] task ${i}`).join("\n")
    );
    boxes.forEach((box) => box.click());
    await settled();
    assert.deepEqual(
      requests.map(({ toggles }) => toggles.length),
      [50, 1],
      "oversized work is split into serialized batches"
    );
    assert.true(
      postModel.raw.split("\n").every((line) => line.startsWith("[x]")),
      "all changes persist"
    );
  });

  test("network failure preserves raw while requiring a fresh baseline", async function (assert) {
    respondWithError = "network";
    const [checkbox] = await prepare("[ ] first");
    await click(checkbox);
    assert.strictEqual(
      postModel.raw,
      "[ ] first",
      "transport failure does not erase shared model data"
    );
    respondWithError = false;
    await click(checkbox);
    assert.strictEqual(
      hydrationRequests,
      1,
      "a later operation revalidates the uncertain baseline"
    );
  });

  test("retires the coordinator after its work drains", async function (assert) {
    const [checkbox] = await prepare("[ ] first");

    checkbox.click();

    assert.strictEqual(
      activeChecklistOperationCountForTesting(),
      1,
      "the active post has one coordinator"
    );
    await settled();
    assert.strictEqual(
      activeChecklistOperationCountForTesting(),
      0,
      "the idle post retains no coordinator"
    );
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

  test("reconciles authoritative content after saving", async function (assert) {
    const [checkbox] = await prepare("[ ] first");

    await click(checkbox);

    assert.strictEqual(
      postModel.last_editor_id,
      1,
      "last editor metadata is reconciled"
    );
    assert.strictEqual(postModel.version, 2, "version metadata is reconciled");
    assert.strictEqual(postModel.raw, "[x] first", "raw content is reconciled");
    assert.strictEqual(
      postModel.cooked,
      "authoritative cooked 1",
      "cooked content is reconciled"
    );
    assert.true(checkbox.isConnected, "the decorated control stays connected");
  });

  test("rebases a desired state after a stale response", async function (assert) {
    holdRequest = true;
    const [checkbox] = await prepare("[ ] first");

    checkbox.click();
    await waitUntil(() => releaseRequest);
    postModel.updated_at = "2026-08-27T08:00:09.000Z";
    postModel.raw = "[ ] first";
    postModel.cooked = "newer cooked";
    responseUpdatedAts = ["2026-08-27T08:00:10.000Z"];
    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await waitUntil(() => requests.length === 2);
    await settled();

    assert.strictEqual(
      requests[1].expected_raw,
      "[ ] first",
      "the retry uses the newer authoritative raw"
    );
    assert.strictEqual(
      postModel.raw,
      "[x] first",
      "the rebased state becomes authoritative"
    );
    assert.strictEqual(
      postModel.cooked,
      "authoritative cooked 2",
      "the rebased cooked state is reconciled"
    );
    assert.strictEqual(
      postModel.updated_at,
      "2026-08-27T08:00:10.000Z",
      "the rebased response advances the timestamp"
    );
  });

  test("does not accept an older version with the same timestamp", async function (assert) {
    holdRequest = true;
    const [checkbox] = await prepare("[ ] first");

    checkbox.click();
    await waitUntil(() => releaseRequest);
    postModel.version = 99;
    postModel.updated_at = "2026-08-27T08:00:01.000Z";
    postModel.cooked = "newer cooked";
    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await settled();

    assert.strictEqual(postModel.version, 99, "the newer version is retained");
    assert.strictEqual(
      postModel.cooked,
      "newer cooked",
      "an older version cannot replace cooked content"
    );
    assert
      .dom(checkbox)
      .doesNotHaveClass(
        "checked",
        "exhausted intent returns to confirmed state"
      );
    assert
      .dom(checkbox)
      .doesNotHaveAttribute("aria-busy", "exhausted intent is no longer busy");
    await waitUntil(() => !checkbox.classList.contains("is-pending"));
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

  test("rejects raw-less work when hydration finds a structural change", async function (assert) {
    hydrationResponse = {
      raw: "[ ] second\n[ ] first",
      updatedAt: "2026-08-27T08:00:01.000Z",
    };
    const [checkbox] = await prepare("[ ] first\n[ ] second", {
      includeRaw: false,
    });

    await click(checkbox);

    assert.strictEqual(hydrationRequests, 1, "the current raw is fetched once");
    assert.strictEqual(requests.length, 0, "no stale target is submitted");
    assert
      .dom(checkbox)
      .doesNotHaveClass("checked", "the optimistic state is reverted");
    assert
      .dom(checkbox)
      .doesNotHaveAttribute("aria-busy", "the stale control is no longer busy");
  });

  test("continues a raw-less operation across teardown", async function (assert) {
    holdHydration = true;
    const [first, second] = await prepare("[ ] first\n[ ] second", {
      includeRaw: false,
    });

    first.click();
    await waitUntil(() => releaseHydration);
    second.click();
    first.click();

    decoratorCleanup();
    decoratorCleanup = null;
    decoratedElement.remove();
    const [firstReplacement, secondReplacement] = await decorate(
      "[ ] first\n[ ] second"
    );

    assert
      .dom(firstReplacement)
      .doesNotHaveClass("checked", "the latest first state is adopted");
    assert
      .dom(firstReplacement)
      .hasClass("is-pending", "the latest first state remains pending");
    assert
      .dom(secondReplacement)
      .hasClass("checked", "the queued second state is adopted");
    assert
      .dom(secondReplacement)
      .hasClass("is-pending", "the queued second state remains pending");

    holdHydration = false;
    releaseHydration();
    releaseHydration = null;
    await waitUntil(() => requests.length === 1);
    await settled();

    assert.deepEqual(
      requests[0].toggles.map(({ checked }) => checked),
      [false, true],
      "all intent captured during hydration uses the hydrated baseline"
    );
  });

  test("keeps accepted raw-less work independent of another rendering", async function (assert) {
    holdHydration = true;
    const [first] = await prepare("[ ] first\n[ ] second", {
      includeRaw: false,
    });

    first.click();
    await waitUntil(() => releaseHydration);
    decoratorCleanup();
    decoratorCleanup = null;
    decoratedElement.remove();
    const [replacement] = await decorate("[ ] second\n[ ] first");

    assert
      .dom(replacement)
      .doesNotHaveClass("checked", "the replacement uses its rendered state");
    assert
      .dom(replacement)
      .doesNotHaveClass("is-pending", "the replacement has no pending work");

    holdHydration = false;
    releaseHydration();
    releaseHydration = null;
    await settled();

    assert.strictEqual(
      requests.length,
      1,
      "the accepted operation is submitted"
    );
    assert.strictEqual(
      requests[0].toggles[0].checkbox_source,
      "0:0",
      "the operation retains its original target"
    );
  });

  test("sends the checkbox count for legacy cooked HTML", async function (assert) {
    const [checkbox] = await prepare("[ ] first\n[ ] second", {
      legacyCooked: true,
    });

    await click(checkbox);

    assert.strictEqual(
      requests[0].toggles[0].checkbox_count,
      2,
      "index lookup includes the rendered count"
    );
  });

  test("persists queued legacy checkboxes", async function (assert) {
    holdRequest = true;
    const [first, second] = await prepare("[ ] first\n[ ] second", {
      legacyCooked: true,
    });

    first.click();
    await waitUntil(() => requests.length === 1);
    second.click();

    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await waitUntil(() => requests.length === 2);
    await settled();

    assert.deepEqual(
      requests.map((request) =>
        request.toggles.map((toggle) => toggle.checkbox_index)
      ),
      [[0], [1]],
      "legacy queue entries remain associated with their indexes"
    );
    assert.strictEqual(
      postModel.raw,
      "[x] first\n[x] second",
      "every queued legacy state is persisted"
    );
  });

  test("continues a legacy operation when sourced cooked appears", async function (assert) {
    holdRequest = true;
    const [checkbox] = await prepare("[ ] first", { legacyCooked: true });

    checkbox.click();
    await waitUntil(() => requests.length === 1);

    decoratorCleanup();
    decoratorCleanup = null;
    decoratedElement.remove();
    const [replacement] = await decorate("[ ] first");

    assert
      .dom(replacement)
      .doesNotHaveClass("checked", "the new rendering uses cooked state");
    assert
      .dom(replacement)
      .doesNotHaveClass("is-pending", "pending UI is not transferred");

    releaseRequest();
    releaseRequest = null;
    await settled();

    assert.strictEqual(
      postModel.raw,
      "[x] first",
      "the accepted legacy operation is persisted"
    );
  });

  test("does not migrate legacy intent across a structural edit", async function (assert) {
    holdRequest = true;
    const [first] = await prepare("[ ] first\n[ ] second", {
      legacyCooked: true,
    });

    first.click();
    await waitUntil(() => requests.length === 1);

    postModel.raw = "[ ] second\n[ ] first";
    postModel.cooked = "structurally newer cooked";
    decoratorCleanup();
    decoratorCleanup = null;
    decoratedElement.remove();
    const [replacement] = await decorate(postModel.raw);

    assert
      .dom(replacement)
      .doesNotHaveClass(
        "checked",
        "legacy intent is not applied to a reordered checkbox"
      );

    releaseRequest();
    releaseRequest = null;
    await settled();

    assert.strictEqual(
      postModel.raw,
      "[ ] second\n[ ] first",
      "the discarded generation does not replace newer raw"
    );
    assert.strictEqual(
      postModel.cooked,
      "structurally newer cooked",
      "the discarded generation does not replace newer cooked"
    );
  });

  test("rejects structure comparisons when both normalizations fail", async function (assert) {
    await prepare("[ ] first");
    postModel.raw = "first invalid raw";
    decoratorCleanup();
    decoratorCleanup = null;
    decoratedElement.remove();
    const [rebound] = await decorate("[ ] first");

    rebound.click();
    postModel.raw = "second invalid raw";
    decoratorCleanup();
    decoratorCleanup = null;
    decoratedElement.remove();
    const [replacement] = await decorate("[ ] first");
    await settled();

    assert
      .dom(replacement)
      .doesNotHaveClass(
        "checked",
        "invalid normalizations cannot preserve intent"
      );
    assert
      .dom(replacement)
      .doesNotHaveClass(
        "is-pending",
        "invalid intent is discarded immediately"
      );
    assert.strictEqual(requests.length, 0, "no invalid baseline is submitted");
  });

  test("rejects a stale rendering after the post structure changes", async function (assert) {
    const [oldFirst] = await prepare("[ ] first\n[ ] second");
    postModel.raw = "[ ] second\n[ ] first";
    postModel.updated_at = "2026-08-27T08:00:01.000Z";

    await click(oldFirst);

    assert.strictEqual(requests.length, 0, "no stale target is submitted");
    assert
      .dom(oldFirst)
      .doesNotHaveClass("checked", "the stale optimistic state is reverted");
    assert
      .dom(oldFirst)
      .doesNotHaveClass("is-interactive", "the stale control is deactivated");
    assert
      .dom(oldFirst)
      .hasAttribute("aria-readonly", "true", "the stale state is communicated");
    assert
      .dom(oldFirst)
      .doesNotHaveAttribute("tabindex", "the stale control leaves tab order");
  });

  test("does not rebase sourced intent across a structural edit", async function (assert) {
    holdRequest = true;
    const [first] = await prepare("[ ] first\n[ ] second");

    first.click();
    await waitUntil(() => requests.length === 1);

    postModel.raw = "[ ] second\n[ ] first";
    postModel.cooked = "newer cooked";
    postModel.updated_at = "2026-08-27T08:00:09.000Z";
    responseUpdatedAts = ["2026-08-27T08:00:10.000Z"];
    decoratorCleanup();
    decoratorCleanup = null;
    decoratedElement.remove();
    const [replacement] = await decorate(postModel.raw);
    replacement.click();

    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await waitUntil(() => requests.length === 2);
    await settled();

    assert.deepEqual(
      requests.map((request) => request.toggles[0].checked),
      [true, true],
      "only the old request and the new post-generation intent are sent"
    );
    assert
      .dom(replacement)
      .hasClass(
        "checked",
        "the new checkbox intent survives the old stale response"
      );
  });

  test("preserves new-generation intent after an old request fails", async function (assert) {
    holdRequest = true;
    const [first] = await prepare("[ ] first\n[ ] second");

    first.click();
    await waitUntil(() => requests.length === 1);

    postModel.raw = "[ ] second\n[ ] first";
    postModel.updated_at = "2026-08-27T08:00:09.000Z";
    responseUpdatedAts = ["2026-08-27T08:00:10.000Z"];
    decoratorCleanup();
    decoratorCleanup = null;
    decoratedElement.remove();
    const [replacement] = await decorate(postModel.raw);
    replacement.click();

    failHeldRequest = true;
    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await waitUntil(() => requests.length === 2);
    await settled();

    assert
      .dom(replacement)
      .hasClass("checked", "the replacement's intent survives the old failure");
    assert.true(
      requests[1].toggles[0].checked,
      "the replacement's intent is persisted"
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

  test("shows pending state on only the changed checkbox", async function (assert) {
    holdRequest = true;
    const [first, second] = await prepare("[ ] first [x] second");
    const initialWidth = first.getBoundingClientRect().width;

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
        "only the pending checkbox is marked busy"
      );
    assert
      .dom(first)
      .doesNotHaveAttribute(
        "aria-disabled",
        "the pending checkbox remains interactive"
      );
    assert
      .dom(first)
      .hasClass("is-pending", "the changed checkbox gets the pending state");
    assert
      .dom(second)
      .doesNotHaveClass(
        "is-pending",
        "an adjacent checkbox does not share the pending state"
      );
    assert
      .dom(second)
      .doesNotHaveAttribute(
        "aria-busy",
        "an adjacent checkbox is not marked busy"
      );
    assert.strictEqual(
      first.getBoundingClientRect().width,
      initialWidth,
      "the pending plate does not change the checkbox footprint"
    );
    assert.strictEqual(
      getComputedStyle(first).animationName,
      "none",
      "the pending treatment does not flash"
    );
    assert
      .dom(".checklist-spinner")
      .doesNotExist("the pending state does not render a spinner");

    releaseRequest();
    await settled();

    assert
      .dom(first)
      .doesNotHaveAttribute("aria-busy", "pending state clears after saving");
    await waitUntil(() => !first.classList.contains("is-pending"));
    assert
      .dom(first)
      .doesNotHaveClass("is-pending", "pending state clears after saving");
    assert
      .dom(first)
      .hasClass("checked", "the optimistic state remains after saving");
  });

  test("persists repeat activation while a request is pending", async function (assert) {
    holdRequest = true;
    const [checkbox] = await prepare("[ ] first");

    checkbox.click();
    await waitUntil(() => requests.length === 1);
    checkbox.click();

    assert
      .dom(checkbox)
      .doesNotHaveClass("checked", "the second click is immediately visible");
    assert
      .dom(checkbox)
      .hasClass(
        "is-pending",
        "the checkbox stays pending for the latest state"
      );
    assert.strictEqual(
      requests.length,
      1,
      "the next save waits for the active request"
    );

    releaseRequest();
    releaseRequest = null;
    await waitUntil(() => requests.length === 2 && releaseRequest);

    assert
      .dom(checkbox)
      .hasClass("is-pending", "pending state stays set between queued saves");
    assert
      .dom(checkbox)
      .hasAttribute("aria-busy", "true", "the queued save remains busy");

    checkbox.click();
    assert
      .dom(checkbox)
      .hasClass("checked", "another click during the queued save is visible");

    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await waitUntil(() => requests.length === 3);
    await settled();

    assert.deepEqual(
      requests.map((request) => request.toggles[0].checked),
      [true, false, true],
      "the server receives the latest state after each active save"
    );
    assert.strictEqual(
      requests[1].expected_raw,
      "[x] first",
      "the queued save uses the prior response as its baseline"
    );
    assert
      .dom(checkbox)
      .hasClass("checked", "the persisted state matches the visible state");
    await waitUntil(() => !checkbox.classList.contains("is-pending"));
    assert
      .dom(checkbox)
      .doesNotHaveClass(
        "is-pending",
        "pending state clears after the final save"
      );
    assert
      .dom(checkbox)
      .hasAttribute(
        "aria-checked",
        "true",
        "ARIA reflects the persisted state"
      );
    assert.strictEqual(
      postModel.raw,
      "[x] first",
      "the model stores the latest persisted state"
    );
  });

  test("preserves ABA intent after the original request fails", async function (assert) {
    holdRequest = true;
    const [checkbox] = await prepare("[ ] first");

    checkbox.click();
    await waitUntil(() => requests.length === 1);
    checkbox.click();
    checkbox.click();

    failHeldRequest = true;
    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await waitUntil(() => requests.length === 2);
    await settled();

    assert.deepEqual(
      requests.map((request) => request.toggles[0].checked),
      [true, true],
      "the repeated final state is sent as a distinct intent after failure"
    );
    assert
      .dom(checkbox)
      .hasClass("checked", "the latest repeated state is preserved");
  });

  test("restores the last confirmed state when a queued save fails", async function (assert) {
    holdRequest = true;
    const [checkbox] = await prepare("[ ] first");

    checkbox.click();
    await waitUntil(() => requests.length === 1);
    checkbox.click();

    holdRequest = false;
    respondWithError = true;
    releaseRequest();
    releaseRequest = null;
    await waitUntil(() => requests.length === 2);
    await settled();

    assert
      .dom(checkbox)
      .hasClass("checked", "the first save's confirmed state is restored");
    assert
      .dom(checkbox)
      .hasAttribute(
        "aria-checked",
        "true",
        "ARIA restores the confirmed state"
      );
    await waitUntil(() => !checkbox.classList.contains("is-pending"));
    assert
      .dom(checkbox)
      .doesNotHaveClass(
        "is-pending",
        "the failed checkbox is no longer pending"
      );
    assert
      .dom(checkbox)
      .doesNotHaveAttribute(
        "aria-busy",
        "the failed checkbox is no longer busy"
      );
    assert.strictEqual(
      postModel.raw,
      "[x] first",
      "the successful save remains reconciled"
    );
  });

  test("coalesces repeat activation back to the active save", async function (assert) {
    holdRequest = true;
    const [checkbox] = await prepare("[ ] first");

    checkbox.click();
    await waitUntil(() => requests.length === 1);
    checkbox.click();
    checkbox.click();

    releaseRequest();
    releaseRequest = null;
    await settled();

    assert.strictEqual(
      requests.length,
      1,
      "no duplicate save is needed when the latest state matches the active save"
    );
    assert
      .dom(checkbox)
      .hasClass("checked", "the latest state remains visible");
    await waitUntil(() => !checkbox.classList.contains("is-pending"));
    assert
      .dom(checkbox)
      .doesNotHaveClass("is-pending", "the matching save clears pending state");
    assert.strictEqual(
      postModel.raw,
      "[x] first",
      "the model reconciles the matching response"
    );
  });

  test("coalesces a rapid sequence before sending", async function (assert) {
    const boxes = await prepare(
      "[ ] first\n[ ] second\n[ ] third\n[ ] fourth\n[ ] fifth\n[ ] sixth"
    );

    boxes.forEach((box) => box.click());
    await settled();

    assert.strictEqual(requests.length, 1, "the sequence sends one request");
    assert.deepEqual(
      requests[0].toggles.map(({ checkbox_index }) => checkbox_index),
      [0, 1, 2, 3, 4, 5],
      "all six changes share the request"
    );
    boxes.forEach((box) =>
      assert.dom(box).hasClass("checked", "each change remains visible")
    );
  });

  test("drops a coalesced change that returns to its confirmed state", async function (assert) {
    const [checkbox] = await prepare("[ ] first");

    checkbox.click();
    checkbox.click();
    await settled();

    assert.strictEqual(requests.length, 0, "no redundant request is sent");
    assert.strictEqual(
      activeChecklistOperationCountForTesting(),
      0,
      "the empty coordinator retires immediately"
    );
    assert
      .dom(checkbox)
      .doesNotHaveClass("checked", "the confirmed state remains visible");
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
      "the in-flight change finishes before the batched backlog"
    );
    assert.strictEqual(
      requests[1].expected_raw,
      "[x] first\n[ ] second\n[ ] third",
      "the second request uses the first response's raw"
    );
    assert.strictEqual(
      requests[1].expected_updated_at,
      "2026-08-27T08:00:01.000Z",
      "the second request uses the first response's revision token"
    );
  });

  test("preserves queued state across an intermediate cooked replacement", async function (assert) {
    holdRequest = true;
    const [first, second] = await prepare("[ ] first\n[ ] second");

    responseCookeds = [(await cook("[x] first\n[ ] second")).toString()];

    first.click();
    await waitUntil(() => releaseRequest);
    second.click();

    releaseRequest();
    releaseRequest = null;
    await waitUntil(() => requests.length === 2 && releaseRequest);

    decoratorCleanup();
    decoratorCleanup = null;
    decoratedElement.remove();
    const [replacementFirst, replacementSecond] = decorateCooked(
      postModel.cooked
    );

    assert
      .dom(replacementFirst)
      .hasClass("checked", "the saved state comes from intermediate cooked");
    assert
      .dom(replacementSecond)
      .hasClass("checked", "the queued state overlays intermediate cooked");
    assert
      .dom(replacementSecond)
      .hasClass("is-pending", "the replacement adopts pending presentation");
    assert
      .dom(replacementSecond)
      .hasAttribute("aria-busy", "true", "the replacement remains busy");

    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await settled();

    assert
      .dom(replacementSecond)
      .hasClass("checked", "the queued state remains after persistence");
    assert
      .dom(replacementSecond)
      .doesNotHaveClass("is-pending", "the pending state clears after saving");
  });

  test("continues queued work after the decorated content is destroyed", async function (assert) {
    holdRequest = true;
    const [first, second] = await prepare("[ ] first\n[ ] second");

    first.click();
    second.click();
    await waitUntil(() => requests.length === 1);
    decoratorCleanup();
    decoratorCleanup = null;

    assert
      .dom(first)
      .doesNotHaveClass("is-pending", "cleanup removes stale presentation");
    assert
      .dom(first)
      .doesNotHaveAttribute("aria-busy", "cleanup removes stale busy state");
    assert
      .dom(second)
      .doesNotHaveClass("is-pending", "queued presentation is also removed");

    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await settled();

    assert.deepEqual(
      requests.map((request) =>
        request.toggles.map((toggle) => toggle.checkbox_index)
      ),
      [[0, 1]],
      "detached controls do not discard the coalesced changes"
    );
    assert.strictEqual(
      postModel.raw,
      "[x] first\n[x] second",
      "the detached model receives the final raw content"
    );
    assert.strictEqual(
      postModel.cooked,
      "authoritative cooked 1",
      "the detached model receives the final cooked content"
    );
  });

  test("rejects clicks from old cooked after a structural conflict", async function (assert) {
    retryableConflicts = [
      {
        raw: "[ ] second\n[ ] first",
        retryable: false,
        updatedAt: "2026-08-27T08:00:10.000Z",
      },
    ];
    const [first] = await prepare("[ ] first\n[ ] second", {
      includeRaw: false,
    });

    await click(first);
    first.click();
    await settled();

    assert.strictEqual(
      requests.length,
      1,
      "old cooked coordinates are not sent against the new baseline"
    );
    assert
      .dom(first)
      .doesNotHaveClass("checked", "the unsafe follow-up intent is discarded");
  });

  test("keeps conflict baselines out of post metadata", async function (assert) {
    holdRequest = true;
    retryableConflicts = [
      {
        raw: "[x] first",
        updatedAt: "2026-08-27T08:00:10.000Z",
      },
    ];
    responseUpdatedAts = ["2026-08-27T08:00:11.000Z"];
    const [checkbox] = await prepare("[ ] first");

    checkbox.click();
    await waitUntil(() => requests.length === 2 && releaseRequest);

    assert.strictEqual(
      postModel.updated_at,
      "2026-08-27T08:00:00.000Z",
      "a conflict baseline does not advance model metadata alone"
    );

    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await settled();
  });

  test("recovers a stale request without discarding its backlog", async function (assert) {
    retryableConflicts = [
      {
        raw: "[x] first\n[ ] second\n[ ] third",
        updatedAt: "2026-08-27T08:00:10.000Z",
      },
    ];
    responseUpdatedAts = [
      "2026-08-27T08:00:11.000Z",
      "2026-08-27T08:00:12.000Z",
    ];
    const [first, second, third] = await prepare(
      "[ ] first\n[ ] second\n[ ] third"
    );

    first.click();
    second.click();
    third.click();
    await waitUntil(() => requests.length === 2);
    await waitUntil(() =>
      [first, second, third].every(
        (checkbox) => !checkbox.classList.contains("is-pending")
      )
    );

    assert.deepEqual(
      requests.map((request) =>
        request.toggles.map((toggle) => toggle.checkbox_index)
      ),
      [
        [0, 1, 2],
        [0, 1, 2],
      ],
      "the coalesced batch is retried together"
    );
    assert.strictEqual(
      requests[1].expected_raw,
      "[x] first\n[ ] second\n[ ] third",
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
    assert.dom(second).hasClass("checked", "the coalesced state is retained");
    assert.dom(third).hasClass("checked", "the coalesced state is retained");
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

  test("recovers after a network error makes the baseline uncertain", async function (assert) {
    respondWithError = "network";
    const [checkbox] = await prepare("[ ] first");

    await click(checkbox);
    await waitUntil(() => !checkbox.hasAttribute("aria-busy"));
    respondWithError = false;
    const currentCheckbox = document.querySelector(
      ".chcklst-box.is-interactive"
    );
    await click(currentCheckbox);

    assert.strictEqual(hydrationRequests, 1, "the baseline is rehydrated");
    assert.strictEqual(requests.length, 2, "the next intent is persisted");
    assert.strictEqual(
      requests[1].expected_raw,
      "[ ] first",
      "the retry uses the hydrated baseline"
    );
    assert.strictEqual(
      postModel.version,
      2,
      "the successful response is applied"
    );
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

    checkbox.dispatchEvent(
      new KeyboardEvent("keydown", {
        bubbles: true,
        cancelable: true,
        key: " ",
        repeat: true,
      })
    );
    assert.dom(checkbox).doesNotHaveClass("checked", "key repeat is ignored");
    assert.strictEqual(requests.length, 0, "key repeat schedules no save");

    await triggerKeyEvent(checkbox, "keydown", " ");
    assert
      .dom(checkbox)
      .hasAttribute("aria-checked", "true", "Space checks the item");

    await waitUntil(() => !checkbox.classList.contains("is-pending"));
    await triggerKeyEvent(checkbox, "keydown", "Enter");
    assert
      .dom(checkbox)
      .hasAttribute("aria-checked", "false", "Enter unchecks the item");
  });

  test("redecorating cleaned controls does not duplicate listeners", async function (assert) {
    const [checkbox] = await prepare("[ ] first");
    decoratorCleanup();
    decoratorCleanup = null;
    const replacementCleanup = checklistSyntax(decoratedElement, {
      getModel: () => postModel,
    });

    await click(checkbox);

    assert.strictEqual(requests.length, 1, "one activation sends one request");
    assert.dom(checkbox).hasClass("checked", "one activation toggles once");

    replacementCleanup();
  });

  test("keeps simultaneous renderings independently interactive", async function (assert) {
    const [firstCheckbox] = await prepare("[ ] first");
    const secondElement = document.createElement("div");
    secondElement.innerHTML = postModel.cooked;
    const secondCleanup = checklistSyntax(secondElement, {
      getModel: () => postModel,
    });
    document.querySelector("#ember-testing").append(secondElement);

    await click(firstCheckbox);

    assert.strictEqual(
      requests.length,
      1,
      "decorating another rendering does not disable the first"
    );

    secondCleanup();
  });

  test("coalesces simultaneous renderings through one coordinator", async function (assert) {
    const [firstCheckbox] = await prepare("[ ] first\n[ ] second");
    const secondElement = document.createElement("div");
    secondElement.innerHTML = postModel.cooked;
    const secondCleanup = checklistSyntax(secondElement, {
      getModel: () => postModel,
    });
    const secondCheckbox = secondElement.querySelectorAll(".chcklst-box")[1];
    document.querySelector("#ember-testing").append(secondElement);

    firstCheckbox.click();
    secondCheckbox.click();
    await settled();

    assert.strictEqual(requests.length, 1, "one coalesced request is sent");
    assert.deepEqual(
      requests[0].toggles.map(({ checkbox_index }) => checkbox_index),
      [0, 1],
      "changes from both renderings share one batch"
    );
    assert.strictEqual(
      postModel.raw,
      "[x] first\n[x] second",
      "both render-local changes are persisted"
    );

    secondCleanup();
  });

  test("serializes later changes from simultaneous renderings", async function (assert) {
    holdRequest = true;
    const [firstCheckbox] = await prepare("[ ] first\n[ ] second");
    const secondElement = document.createElement("div");
    secondElement.innerHTML = postModel.cooked;
    const secondCleanup = checklistSyntax(secondElement, {
      getModel: () => postModel,
    });
    const secondCheckbox = secondElement.querySelectorAll(".chcklst-box")[1];
    document.querySelector("#ember-testing").append(secondElement);

    firstCheckbox.click();
    await waitUntil(() => requests.length === 1);
    secondCheckbox.click();

    assert.strictEqual(
      requests.length,
      1,
      "the second rendering waits for the active request"
    );

    holdRequest = false;
    releaseRequest();
    releaseRequest = null;
    await waitUntil(() => requests.length === 2);
    await settled();

    assert.strictEqual(
      requests[1].expected_raw,
      "[x] first\n[ ] second",
      "the second rendering uses the coordinated baseline"
    );
    assert.strictEqual(
      postModel.raw,
      "[x] first\n[x] second",
      "both serialized changes are persisted"
    );

    secondCleanup();
  });

  test("cleans up simultaneous renderings independently", async function (assert) {
    await prepare("[ ] first");
    const secondElement = document.createElement("div");
    secondElement.innerHTML = postModel.cooked;
    const secondCleanup = checklistSyntax(secondElement, {
      getModel: () => postModel,
    });
    const secondCheckbox = secondElement.querySelector(".chcklst-box");
    document.querySelector("#ember-testing").append(secondElement);

    decoratorCleanup();
    decoratorCleanup = null;
    await click(secondCheckbox);

    assert.strictEqual(
      requests.length,
      1,
      "cleaning one rendering leaves the other interactive"
    );

    secondCleanup();
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

  test("only anonymous quote checkboxes are interactive", async function (assert) {
    const [attributedQuote, postQuote, anonymousQuote, own] = await prepare(
      '[quote="Other user"]\n[ ] attributed task\n[/quote]\n\n[quote=", post: 1"]\n[ ] post task\n[/quote]\n\n[quote]\n[ ] anonymous task\n[/quote]\n\n[ ] own task'
    );

    for (const [quote, label] of [
      [attributedQuote, "attributed"],
      [postQuote, "post"],
    ]) {
      assert
        .dom(quote)
        .hasAttribute(
          "aria-readonly",
          "true",
          `the ${label} quote checkbox is read-only`
        );
      assert
        .dom(quote)
        .doesNotHaveAttribute(
          "tabindex",
          `the ${label} quote checkbox is not focusable`
        );
      await click(quote);
    }
    assert.strictEqual(requests.length, 0, "sourced quotes send no request");

    assert
      .dom(anonymousQuote)
      .hasAttribute(
        "tabindex",
        "0",
        "the anonymous quote checkbox is interactive"
      );
    await click(anonymousQuote);
    assert.strictEqual(requests.length, 1, "the anonymous quote toggles");
    assert.strictEqual(
      requests[0].toggles[0].checkbox_index,
      0,
      "sourced quote checkboxes are excluded from the rendered index"
    );

    await click(own);
    assert.strictEqual(requests.length, 2, "the post's own checkbox toggles");
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
