import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  finding,
  findingKey,
  findingTrace,
  isProblem,
  ruleIds,
  tierOf,
} from "discourse/static/dev-tools/a11y/findings";

/**
 * Oracle for the finding catalogue and its tiers (unit 1b).
 *
 * The table below is the reviewed catalogue, transcribed. It is duplicated here
 * on purpose: the registry is the panel's whole editorial position on what
 * counts as a defect, and a tier that drifts silently turns the Problems filter
 * back into the noise this rewrite exists to remove. Changing a tier should
 * require changing this table, in a diff someone reads.
 *
 * `broken` colours the row and feeds the Problems filter. `fragile` works in
 * some assistive tech and not others, and is excluded from that filter.
 * `noted` is true but not a defect, and never enters the filter or a sweep.
 *
 * Rules carry no English. They emit an id and parameters; the panel renders the
 * translation. That split is what keeps a pasted trace stable across locales,
 * and it is why `findingTrace` below is asserted byte-for-byte.
 */
const CATALOGUE = {
  "focus.not-in-tree": "broken",
  "focus.no-name": "broken",

  "cursor.dangling": "broken",
  "cursor.target-hidden": "broken",
  "cursor.not-item": "broken",
  "cursor.claim-missing": "fragile",
  // Split by whether the visual marker is a contract or a convention. Under a
  // modifier that owns both the class and the attribute, divergence is a defect;
  // where the marker is only a styling convention, it is an observation.
  "cursor.visual-diverged": "broken",
  "cursor.visual-diverged-conventional": "noted",

  "set.impossible": "broken",
  "set.disagrees": "noted",

  // One id per tier rather than one per role/attribute pair: which attribute is
  // missing is a parameter, not a separate rule.
  "role.missing-state": "broken",
  "role.missing-attribute": "fragile",
  "role.missing-attribute-defaulted": "noted",

  "name.describedby-echoes-name": "fragile",
  "name.from-title-only": "noted",
  "name.title-duplicates-name": "noted",
  "name.labelledby-partly-unresolved": "noted",

  "live.born-with-content": "broken",
  // `role="alert"` may raise a platform alert event on insertion, so the same
  // markup is a defect under a plain `aria-live` and merely unreliable here.
  "live.born-with-content-alert": "fragile",
  "live.replaced-mid-session": "broken",
  "live.not-in-tree": "broken",
  "live.politeness-contradicts-role": "broken",
  // One rule, not two. An earlier draft split this by role, on the strength of a
  // claim that a live-region role plus an explicit `aria-live` double-speaks on
  // VoiceOver iOS. No source says that. What is documented is that the pair is
  // redundant, and that every extra permutation is one more thing an assistive
  // technology can get wrong — which justifies reporting it and nothing more.
  "live.redundant-politeness": "noted",

  "announce.no-region": "broken",
  "announce.undelivered": "broken",
  "announce.text-mismatch": "noted",
  "announce.runaway": "fragile",
};

module("Unit | Lib | dev-tools | a11y-findings", function (hooks) {
  setupTest(hooks);

  test("the registry is exactly the reviewed catalogue", function (assert) {
    assert.deepEqual(
      [...ruleIds()].sort(),
      Object.keys(CATALOGUE).sort(),
      "no rule ships without review, and none is quietly dropped"
    );

    for (const [id, tier] of Object.entries(CATALOGUE)) {
      assert.strictEqual(tierOf(id), tier, `${id} is ${tier}`);
    }
  });

  test("rule ids are stable lowercase slugs", function (assert) {
    for (const id of ruleIds()) {
      assert.true(
        /^[a-z]+(?:\.[a-z0-9]+(?:-[a-z0-9]+)*)+$/.test(id),
        `${id} is a slug a trace and a translation key can both carry`
      );
    }
  });

  test("the id list cannot be edited into the registry", function (assert) {
    assert.throws(
      () => ruleIds().push("made.up"),
      "the registry is not handed out mutable"
    );
    assert.strictEqual(
      tierOf("made.up"),
      undefined,
      "and nothing was added by trying"
    );
  });

  // Reading is safe, constructing is not: a typo in a detector must fail loudly
  // at the point of the typo rather than emit a row the panel cannot tier,
  // colour, filter or translate.
  test("an unregistered id throws rather than producing an untiered finding", function (assert) {
    assert.strictEqual(tierOf("cursor.dngling"), undefined, "reading is safe");

    let thrown;
    try {
      finding("cursor.dngling");
    } catch (error) {
      thrown = error;
    }

    assert.true(thrown instanceof Error, "constructing throws");
    assert.true(
      thrown.message.includes("cursor.dngling"),
      "the message names the id, because that is the typo"
    );
    assert.true(
      /not registered|unknown/i.test(thrown.message),
      "and says what is wrong with it, so the id alone is not the whole message"
    );
  });

  test("a finding carries its own tier", function (assert) {
    assert.strictEqual(finding("cursor.dangling").tier, "broken");
    assert.strictEqual(finding("set.disagrees").tier, "noted");
    assert.strictEqual(finding("cursor.dangling").id, "cursor.dangling");
  });

  // Findings are recorded once and rendered much later, off a timeline that
  // outlives the DOM they describe. A recorded row that can still be edited is
  // a row that can disagree with the trace someone already pasted.
  test("a finding is frozen, and does not alias its caller's object", function (assert) {
    const params = { id: "ember42" };
    const recorded = finding("cursor.dangling", params);

    assert.true(Object.isFrozen(recorded), "the finding");
    assert.true(Object.isFrozen(recorded.params), "and its params");

    params.id = "ember99";

    assert.strictEqual(
      recorded.params.id,
      "ember42",
      "the caller kept no handle on it"
    );
  });

  test("isProblem is true for exactly the broken rules", function (assert) {
    for (const id of ruleIds()) {
      assert.strictEqual(
        isProblem(finding(id)),
        tierOf(id) === "broken",
        `${id} (${tierOf(id)})`
      );
    }
  });

  // Asserted byte-for-byte because this string is what a pasted bug report
  // carries and what the panel's text filter matches. Any English reaching it
  // would make both locale-dependent.
  test("a trace line is the id and its params, in order, and nothing else", function (assert) {
    assert.strictEqual(
      findingTrace(
        finding("cursor.dangling", { id: "ember42", composite: "listbox" })
      ),
      "cursor.dangling id=ember42 composite=listbox"
    );

    assert.strictEqual(
      findingTrace(finding("set.impossible", { posinset: 0, setsize: 5 })),
      "set.impossible posinset=0 setsize=5",
      "numbers render bare"
    );

    assert.strictEqual(
      findingTrace(finding("live.redundant-politeness")),
      "live.redundant-politeness",
      "and a rule with nothing to say says only its own name"
    );
  });

  test("the translation key is derived from the id", function (assert) {
    assert.strictEqual(
      findingKey("live.born-with-content"),
      "dev_tools.a11y.findings.live.born_with_content"
    );
    assert.strictEqual(
      findingKey("focus.no-name"),
      "dev_tools.a11y.findings.focus.no_name"
    );
  });

  test("every registered rule derives a distinct translation key", function (assert) {
    const keys = ruleIds().map(findingKey);

    assert.strictEqual(
      new Set(keys).size,
      keys.length,
      "no two rules collide onto one string"
    );
  });
});
