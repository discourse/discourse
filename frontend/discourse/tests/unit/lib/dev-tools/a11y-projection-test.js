import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { finding } from "discourse/static/dev-tools/a11y/findings";
// Namespace import on purpose: a named import of something not yet exported
// fails at link time and takes the whole module down, which reads as a broken
// suite rather than as an assertion failing.
import * as projection from "discourse/static/dev-tools/a11y/projection";
import { subjectKey } from "discourse/static/dev-tools/a11y/subject";

/**
 * Oracle for the timeline projection (unit 2a).
 *
 * A record is what happened; a row is what a reader looks at. They are not the
 * same shape, and the three places they differ are the whole of this unit:
 *
 * An announcement and the delivery that answered it are ONE row spanning two
 * records — printing the string twice added nothing. A burst of the same event is
 * one row standing for many. And third-party live-region churn is one row
 * standing for a great deal of noise nobody asked about; in a real capture it is
 * roughly sixty percent of the timeline.
 *
 * Projection never changes what was recorded, which is the constraint every
 * assertion here is written against: the raw entries survive untouched and every
 * row points back at the sequence numbers it stands for.
 */
module("Unit | Lib | dev-tools | a11y-projection", function (hooks) {
  setupTest(hooks);

  let nextSeq;

  hooks.beforeEach(function () {
    nextSeq = 1;
  });

  /** An entry with the fields projection reads and nothing else. */
  function entry(kind, label, extra = {}) {
    return {
      seq: nextSeq++,
      at: 0,
      elapsedMs: undefined,
      kind,
      label,
      detail: "",
      findings: [],
      ...extra,
    };
  }

  function event(label, extra) {
    return entry("event", label, extra);
  }

  function rowsOf(entries) {
    return projection.project(entries).rows;
  }

  function shapeOf(entries) {
    return rowsOf(entries).map(({ kind, seqLabel }) => `${kind} ${seqLabel}`);
  }

  test("an ordinary entry is one row that names its own record", function (assert) {
    const [row] = rowsOf([event("click")]);

    assert.strictEqual(row.kind, "atomic");
    assert.strictEqual(row.seqLabel, "#1");
    assert.deepEqual(row.members, [1], "and points back at what it stands for");
    assert.strictEqual(
      row.id,
      subjectKey(row.subject),
      "identity is the subject's, so selection and projection cannot disagree"
    );
  });

  /*
   * The merge that motivates the unit. Two rows printed the same sentence twice.
   */
  test("an announcement and its delivery are one row", function (assert) {
    const rows = rowsOf([
      entry("intent", "announce polite", { message: "twelve results" }),
      entry("delivered", "delivered polite", { intentSeq: 1, latencyMs: 12 }),
    ]);

    assert.strictEqual(rows.length, 1, "one row, not two");
    assert.strictEqual(rows[0].kind, "pair");
    assert.deepEqual(
      rows[0].members,
      [1, 2],
      "both records are reachable, which is what lets the row carry both markers"
    );
    assert.strictEqual(
      rows[0].latencyMs,
      12,
      "latency measures the announcement and rides with the sentence"
    );
  });

  /*
   * A delivery usually follows its intent immediately, and then a range claims
   * nothing untrue because there is nothing in between to claim. The arrow is for
   * the case where a range WOULD lie, and reserving it for that is what makes it
   * mean something when it appears.
   */
  test("a pair whose records are adjacent reads as a range", function (assert) {
    const rows = rowsOf([
      entry("intent", "announce polite", { message: "saved" }),
      entry("delivered", "delivered polite", { intentSeq: 1 }),
    ]);

    assert.strictEqual(rows[0].seqLabel, "#1–2");
  });

  /*
   * `seq` is allocated per raw record, and the intent records synchronously while
   * the delivery arrives later from a mutation observer, so anything recording in
   * between separates them. A range would claim every record between the two
   * belongs to this row.
   */
  test("a pair states two sequences without claiming the span between them", function (assert) {
    const rows = rowsOf([
      entry("intent", "announce polite", { message: "saved" }),
      event("focusin"),
      event("click"),
      entry("delivered", "delivered polite", { intentSeq: 1 }),
    ]);

    const pair = rows.find((row) => row.kind === "pair");
    assert.strictEqual(
      pair.seqLabel,
      "#1 → #4",
      "endpoint notation, because the two rows between are not part of this one"
    );
    assert.strictEqual(
      rows.length,
      3,
      "and those two rows are still their own"
    );
  });

  // Front eviction takes the oldest, so it is always the intent that goes first.
  // The row survives as a pair because the delivery still claims the intent; what
  // is gone is one endpoint, and the label says so rather than inventing a number.
  test("a delivery whose intent has been evicted is a pair with one endpoint", function (assert) {
    nextSeq = 40;
    const rows = rowsOf([
      entry("delivered", "delivered polite", { intentSeq: 12 }),
    ]);

    assert.strictEqual(rows[0].kind, "pair");
    assert.strictEqual(rows[0].seqLabel, "→ #40");
    assert.deepEqual(rows[0].members, [40], "only the record that survived");
    assert.strictEqual(
      rows[0].id,
      subjectKey(rows[0].subject),
      "and it is still selectable as the pair it belongs to"
    );
  });

  // Nothing answered it, so there is no pair to make. An intent alone is its own
  // row, and reporting it as half a pair would imply a delivery that never came.
  test("an intent nothing answered is an ordinary row", function (assert) {
    const rows = rowsOf([
      entry("intent", "announce polite", { message: "saved" }),
    ]);

    assert.strictEqual(rows[0].kind, "atomic");
    assert.strictEqual(rows[0].seqLabel, "#1");
  });

  test("a burst of the same event collapses to one row", function (assert) {
    const rows = rowsOf([
      event("focusin"),
      event("focusin"),
      event("focusin"),
      event("focusin"),
    ]);

    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].kind, "run");
    assert.strictEqual(
      rows[0].seqLabel,
      "#1–4",
      "a run's members are adjacent, so a range is honest here"
    );
    assert.strictEqual(rows[0].count, 4);
    assert.true(rows[0].quiet, "a run sits on the noise floor");
  });

  // The reviewed mockup's own values, because every other label assertion here
  // uses single digits and so cannot catch formatting that is sensitive to how
  // many digits a sequence has.
  test("a run of the mockup's size carries the mockup's label", function (assert) {
    nextSeq = 154;
    const rows = rowsOf(Array.from({ length: 66 }, () => event("focusin")));

    assert.strictEqual(rows[0].seqLabel, "#154–219");
    assert.strictEqual(rows[0].count, 66);
  });

  /*
   * A FINDING BLOCKS THE MERGE, and this is the one grouping rule whose absence
   * would defeat the panel rather than merely annoy.
   *
   * Clean repetition is noise, which is what collapsing exists for. Repetition
   * CONTAINING a defect is the thing the panel was opened to find — so a run that
   * swallowed the one row carrying a finding would hide the only row that mattered,
   * on the noise floor, dimmed, behind a disclosure.
   *
   * Never merges, not "merges with its own kind": two adjacent defective rows are two
   * defects, and one row claiming both is a count nobody asked for.
   */
  test("a row carrying a finding never merges", function (assert) {
    const noName = () => [finding("focus.no-name")];

    assert.deepEqual(
      shapeOf([
        event("focusin"),
        event("focusin", { findings: noName() }),
        event("focusin"),
        event("focusin"),
      ]),
      ["atomic #1", "atomic #2", "run #3–4"],
      "the defective row stands alone and the clean pair still collapses"
    );

    // The helper allocates sequences as it builds, and the fixture above consumed
    // four of them, so this one starts where that left off.
    nextSeq = 1;
    assert.deepEqual(
      shapeOf([
        event("focusin", { findings: noName() }),
        event("focusin", { findings: noName() }),
      ]),
      ["atomic #1", "atomic #2"],
      "and two defects are two rows, not one row claiming both"
    );
  });

  // A run of one is a contradiction: there is nothing collapsed and nothing to
  // expand, and putting a lone event on the noise floor hides it for no gain.
  test("a single event is not a run of one", function (assert) {
    const rows = rowsOf([event("focusin"), event("click"), event("focusin")]);

    assert.deepEqual(
      rows.map((row) => row.kind),
      ["atomic", "atomic", "atomic"]
    );
    assert.false(rows[0].quiet, "and nothing recedes");
  });

  test("a run ends where a different kind interleaves", function (assert) {
    assert.deepEqual(
      shapeOf([
        event("focusin"),
        event("focusin"),
        event("click"),
        event("focusin"),
        event("focusin"),
      ]),
      ["run #1–2", "atomic #3", "run #4–5"],
      "two runs, because the click is not part of either"
    );
  });

  /*
   * A run's timing is the gap from the row BEFORE it, never a sum over its
   * members. A sum would be a duration wearing the notation of an interval, and
   * the right margin means one thing everywhere.
   */
  test("a run's elapsed is the gap before it, not a total", function (assert) {
    const rows = rowsOf([
      event("click", { elapsedMs: 500 }),
      event("focusin", { elapsedMs: 40 }),
      event("focusin", { elapsedMs: 30 }),
      event("focusin", { elapsedMs: 20 }),
    ]);

    assert.strictEqual(
      rows[1].elapsedMs,
      40,
      "the gap from the click to the run's first member"
    );
  });

  /*
   * Sixty identical findings is one problem observed sixty times, and a row that
   * listed each would drown the finding it is reporting. Equivalence is per rule,
   * so two findings of the same rule with the same parameters are one.
   */
  test("a run reports each distinct finding once", function (assert) {
    const noName = () => [finding("focus.no-name")];
    const rows = rowsOf([
      event("focusin", { findings: noName() }),
      event("focusin", { findings: noName() }),
      event("focusin", { findings: noName() }),
    ]);

    assert.deepEqual(
      rows[0].findings.map(({ id }) => id),
      ["focus.no-name"],
      "one problem, observed three times"
    );
  });

  // Same rule, different subject. Collapsing these would report one dangling
  // cursor where there were two different ones.
  /*
   * Both findings on ONE record, deliberately. This used to spread them across two
   * records and read the merged row's list — which quietly required two defective
   * rows to merge, and a finding blocks the merge. The claim being made is about
   * DEDUPLICATION, not about grouping, so the fixture should not depend on grouping
   * at all.
   */
  test("findings of one rule with different parameters stay distinct", function (assert) {
    const rows = rowsOf([
      event("keydown", {
        findings: [
          finding("cursor.dangling", { id: "a" }),
          finding("cursor.dangling", { id: "b" }),
        ],
      }),
    ]);

    assert.strictEqual(
      rows[0].findings.length,
      2,
      "the parameters are part of what makes a finding the same finding"
    );
  });

  test("equivalence is by rule and parameters, not object identity", function (assert) {
    const key = projection.findingEquivalenceKey;

    assert.strictEqual(
      key(finding("cursor.dangling", { id: "a" })),
      key(finding("cursor.dangling", { id: "a" })),
      "two recordings of the same problem"
    );
    assert.notStrictEqual(
      key(finding("cursor.dangling", { id: "a" })),
      key(finding("cursor.dangling", { id: "b" })),
      "and two different ones"
    );
  });

  // Parameters are recorded in whatever order the rule happened to build them, so
  // equivalence that depended on insertion order would report the same problem
  // twice depending on which code path found it.
  test("equivalence does not depend on the order parameters were built in", function (assert) {
    const key = projection.findingEquivalenceKey;

    assert.strictEqual(
      key(finding("cursor.not-item", { role: "option", id: "a" })),
      key(finding("cursor.not-item", { id: "a", role: "option" })),
      "same rule, same parameters, different insertion order"
    );
  });

  /*
   * The rail carries severity and nothing else, so it answers one question: is
   * there something wrong here. `noted` is true but not a defect, so it never
   * colours a row — that indiscriminate colouring is the failure the catalogue
   * was rebuilt to fix.
   */
  test("severity is the worst finding on the row, and noted is not one", function (assert) {
    const severityOf = (id) =>
      rowsOf([event("focusin", { findings: [finding(id)] })])[0].severity;

    assert.strictEqual(severityOf("focus.no-name"), "danger", "broken");
    assert.strictEqual(
      severityOf("name.describedby-echoes-name"),
      "highlight",
      "fragile"
    );
    assert.strictEqual(severityOf("set.disagrees"), "none", "noted");
    assert.strictEqual(
      rowsOf([event("focusin")])[0].severity,
      "none",
      "and a clean row is clean"
    );
  });

  test("one broken finding outranks any number of quieter ones", function (assert) {
    const rows = rowsOf([
      event("focusin", {
        findings: [
          finding("set.disagrees"),
          finding("focus.no-name"),
          finding("name.describedby-echoes-name"),
        ],
      }),
    ]);

    assert.strictEqual(rows[0].severity, "danger");
  });

  /*
   * Third-party churn. One browser extension cycling its live region produces
   * left / replaced / joined dozens of times, and grouping it is what makes the
   * rest of the capture readable.
   */
  test("live-region churn for one region collapses to one row", function (assert) {
    const churn = (label) =>
      entry("meta", label, { regionKey: "id:ext-region" });
    const rows = rowsOf([
      churn("live region left"),
      churn("live region joined"),
      churn("live region left"),
      churn("live region joined"),
    ]);

    assert.strictEqual(rows.length, 1);
    assert.strictEqual(rows[0].kind, "churn");
    assert.strictEqual(rows[0].count, 4);
    assert.true(rows[0].quiet, "churn sits on the same noise floor as a run");
  });

  /*
   * The contradiction the red team caught, and the reason grouping, finding
   * equivalence and run identity are one unit.
   *
   * `live.replaced-mid-session` fires on EVERY replacement whose predecessor had
   * delivered — which is exactly what a cycling extension does dozens of times. So
   * every `replaced` row inside real churn carries a BROKEN finding, and "a finding
   * blocks the merge" then forbids collapsing the very rows churn grouping exists to
   * collapse. Neither rule is wrong alone; together they cancel.
   *
   * The resolution weakens neither: a finding blocks the merge of rows that DIFFER,
   * and aggregates across rows repeating the SAME finding on the SAME subject. The
   * group states it once with a count, because printing a true defect two dozen times
   * is the flag-everything failure in new clothes — unaggregated true positives bury
   * the list just as effectively as false ones.
   */
  function churnCycle(regionKey, times, { split } = {}) {
    const replaced = (index) =>
      entry("event", "live region replaced", {
        regionKey,
        findings: [
          finding(
            split === index
              ? "live.born-with-content"
              : "live.replaced-mid-session",
            { channel: "polite", region: regionKey }
          ),
        ],
      });

    return Array.from({ length: times }, (_, index) => [
      entry("meta", "live region left", { regionKey }),
      replaced(index),
      entry("meta", "live region joined", { regionKey }),
    ]).flat();
  }

  test("churn aggregates a finding that repeats on the same subject", function (assert) {
    const rows = rowsOf(churnCycle("id:ext-region", 4));

    assert.strictEqual(rows.length, 1, "the whole cycle is one row");
    assert.strictEqual(rows[0].kind, "churn");
    assert.deepEqual(
      rows[0].findings.map(({ id }) => id),
      ["live.replaced-mid-session"],
      "stated once, not four times"
    );
    assert.strictEqual(
      rows[0].count,
      12,
      "and the count says how much it stands for"
    );
  });

  /*
   * The point of declaring subject params rather than comparing all of them.
   *
   * The fixture above holds the region AND the channel constant, so it cannot tell
   * "the subject is the region" from "the subject is everything in params" — both
   * aggregate it. Varying only the INCIDENTAL parameter separates them: a channel
   * that differs must not split the group, because the same region replacing itself
   * is one story however it was announcing at the time.
   *
   * The opposite mistake is just as available: comparing all params would never
   * aggregate anything, since `announce.undelivered` embeds a unique intent sequence
   * and `announce.runaway` a count that changes on every occurrence.
   */
  test("an incidental parameter changing does not split the group", function (assert) {
    const region = "id:ext-region";
    const cycle = (channel) => [
      entry("meta", "live region left", { regionKey: region }),
      entry("event", "live region replaced", {
        regionKey: region,
        findings: [finding("live.replaced-mid-session", { channel, region })],
      }),
      entry("meta", "live region joined", { regionKey: region }),
    ];

    const rows = rowsOf([
      ...cycle("polite"),
      ...cycle("assertive"),
      ...cycle("polite"),
    ]);

    assert.strictEqual(
      rows.length,
      1,
      "the channel is incidental, so the cycle is still one story"
    );
    assert.deepEqual(
      rows[0].findings.map(({ id }) => id),
      ["live.replaced-mid-session"],
      "and the finding is still stated exactly once"
    );
  });

  /*
   * The negative fixture the plan insists on, because the positive one alone passes
   * an implementation that swallows ANY finding it meets mid-cycle. A different
   * finding is a different story and must not be absorbed into the noise.
   */
  test("a different finding inside the cycle splits the group", function (assert) {
    const shape = shapeOf(churnCycle("id:ext-region", 4, { split: 2 }));

    assert.true(
      shape.length > 1,
      `the odd finding breaks the group, got ${shape.join(", ")}`
    );
    assert.true(
      rowsOf(churnCycle("id:ext-region", 4, { split: 2 })).some((row) =>
        row.findings.some(({ id }) => id === "live.born-with-content")
      ),
      "and the finding that differs is still reported somewhere"
    );
  });

  // Two regions cycling at once is two stories, and merging them would report a
  // count that belongs to neither.
  test("churn for different regions does not merge", function (assert) {
    const rows = rowsOf([
      entry("meta", "live region left", { regionKey: "id:one" }),
      entry("meta", "live region joined", { regionKey: "id:one" }),
      entry("meta", "live region left", { regionKey: "id:two" }),
      entry("meta", "live region joined", { regionKey: "id:two" }),
    ]);

    assert.strictEqual(rows.length, 2, "one row per region");
    assert.deepEqual(
      rows.map((row) => row.count),
      [2, 2]
    );
  });

  /*
   * Tab moves focus as the default action of keydown, so the press and the focus
   * change it caused are one interaction. Capture records both, in causal order;
   * the row is where they become one thing.
   */
  test("a keypress and the focus change it caused are one row", function (assert) {
    const rows = rowsOf([
      event("keydown", { keys: ["Tab"], code: "Tab" }),
      event("focusin"),
    ]);

    assert.strictEqual(rows.length, 1, "one interaction, one row");
    assert.deepEqual(
      rows[0].members,
      [1, 2],
      "and both records stay reachable"
    );
  });

  // A focus change nobody caused is its own row. Programmatic focus moves are a
  // class of accessibility bug, so folding them into an unrelated press would
  // hide exactly the case worth seeing.
  test("a focus change with no preceding press stands on its own", function (assert) {
    const rows = rowsOf([event("focusin"), event("click")]);

    assert.deepEqual(
      rows.map((row) => row.members),
      [[1], [2]]
    );
  });

  /*
   * The reason row ids exist. A row is selected while the timeline is still
   * recording, so every new entry re-projects the list — and a selection that
   * moved or dropped on each new event would be unusable during exactly the live
   * capture the panel is for.
   */
  test("ids are stable as the timeline grows", function (assert) {
    const before = [
      event("click"),
      event("focusin"),
      event("focusin"),
      event("focusin"),
    ];
    const idsBefore = rowsOf(before).map((row) => row.id);

    nextSeq = 5;
    const idsAfter = rowsOf([...before, event("focusin"), event("click")]).map(
      (row) => row.id
    );

    assert.deepEqual(
      idsAfter.slice(0, idsBefore.length),
      idsBefore,
      "the rows that were there keep the identity they were selected by"
    );
  });

  test("a growing run keeps the id it was selected by", function (assert) {
    const three = [event("focusin"), event("focusin"), event("focusin")];
    const [runBefore] = rowsOf(three);

    nextSeq = 4;
    const [runAfter] = rowsOf([...three, event("focusin"), event("focusin")]);

    assert.strictEqual(
      runAfter.id,
      runBefore.id,
      "the same run, three members longer"
    );
    assert.strictEqual(runAfter.count, 5, "and it says so");
  });

  /*
   * The projection is also what makes a subject resolvable. `resolveSubject`
   * decides whether a selected run is present by looking for a surviving member,
   * which means a record has to carry the run it belongs to — and only the
   * projection knows that.
   */
  test("the projection annotates records with the run they belong to", function (assert) {
    const { records } = projection.project([
      event("click"),
      event("focusin"),
      event("focusin"),
    ]);

    assert.deepEqual(
      records.map(({ seq, runStartedAtSeq }) => [seq, runStartedAtSeq]),
      [
        [1, undefined],
        [2, 2],
        [3, 2],
      ],
      "both run members name the sequence their run started at"
    );
    assert.strictEqual(
      records[1].groupingKey,
      records[2].groupingKey,
      "and agree on which run that is"
    );
  });

  // Projection is a view, not a rewrite. The raw records are what a pasted trace
  // and the existing instrumentation tests read, and they have to survive it.
  test("projecting does not mutate the entries it reads", function (assert) {
    const entries = [
      entry("intent", "announce polite", { message: "saved" }),
      entry("delivered", "delivered polite", { intentSeq: 1 }),
      event("focusin"),
      event("focusin"),
    ];
    const before = structuredClone(entries);

    projection.project(entries);

    assert.deepEqual(entries, before, "read, never written");
  });

  test("an empty timeline projects to no rows", function (assert) {
    assert.deepEqual(rowsOf([]), [], "and does not throw doing it");
  });
});
