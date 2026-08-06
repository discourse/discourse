import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
// Namespace import on purpose: a named import of something not yet exported
// fails at link time and takes the whole module down, which reads as a broken
// suite rather than as an assertion failing.
import * as subject from "discourse/static/dev-tools/a11y/subject";

/**
 * Oracle for the selected-subject model (unit 0c).
 *
 * The panel selects by storing a single sequence number and resolving it with
 * `timelineEntries().find(...)`. Three things are wrong with that, and all three
 * block the views that come after it.
 *
 * A sequence number cannot NAME everything the panel now needs to select. A
 * collapsed run of sixty focus events is one row, an announce merged with its
 * delivery is one row spanning two records, and a live region is not a timeline
 * record at all — but each of them is something a person clicks and expects
 * detail for.
 *
 * `find` returns undefined for a subject the 200-entry ring has evicted, which
 * is indistinguishable from nothing being selected. The detail panel then goes
 * blank with no account of why, during exactly the activity — a long live
 * capture — that causes it.
 *
 * And a run grows. Events keep merging into it while it is selected, so its
 * identity cannot be derived from its extent.
 */
module("Unit | Lib | dev-tools | a11y-subject", function (hooks) {
  setupTest(hooks);

  /** A record set standing in for the timeline, oldest first. */
  function records(...seqs) {
    return seqs.map((seq) => ({ seq, kind: "event" }));
  }

  /*
   * A record set whose members all belong to one run, oldest first.
   *
   * A run subject knows the sequence it started at and never its extent, so
   * whether it is partly or wholly evicted is not answerable from the subject.
   * It is answerable from the records: a surviving member still carries the run
   * it belongs to. Two runs can share a grouping key, which is why membership is
   * the start sequence and not the key.
   */
  function runRecords(groupingKey, startedAtSeq, ...seqs) {
    return seqs.map((seq) => ({
      seq,
      kind: "event",
      groupingKey,
      runStartedAtSeq: startedAtSeq,
    }));
  }

  test("a subject is identified by a stable string, whatever its kind", function (assert) {
    const keys = [
      subject.entrySubject(12),
      subject.pairSubject(12),
      subject.runSubject("focusin", 12),
      subject.regionSubject("id:a11y-polite-region"),
    ].map(subject.subjectKey);

    assert.strictEqual(
      new Set(keys).size,
      keys.length,
      "four different subjects, four different identities"
    );
    assert.true(
      keys.every((key) => typeof key === "string" && key.length > 0),
      "a selection has to survive being written down and compared"
    );
  });

  // An entry and a merged pair can share a sequence number, and mean different
  // things. Keying on the number alone would make selecting one select both.
  test("kind is part of identity, not decoration", function (assert) {
    assert.notStrictEqual(
      subject.subjectKey(subject.entrySubject(12)),
      subject.subjectKey(subject.pairSubject(12)),
      "the intent's own row and the merged pair are different selections"
    );
  });

  test("a present entry resolves", function (assert) {
    const found = subject.resolveSubject(subject.entrySubject(12), {
      records: records(10, 11, 12, 13),
      regionKeys: [],
    });

    assert.strictEqual(found.state, "present");
    assert.strictEqual(
      found.record?.seq,
      12,
      "and hands back what it resolved"
    );
  });

  /*
   * The distinction the current code cannot make. "Evicted" and "nothing is
   * selected" have to be different answers, because the panel owes the reader a
   * different sentence for each — and eviction is silent, routine, and happens
   * mid-capture.
   */
  test("an evicted entry is reported as evicted, not as absent", function (assert) {
    const found = subject.resolveSubject(subject.entrySubject(4), {
      records: records(10, 11, 12),
      regionKeys: [],
      oldestRetainedSeq: 10,
    });

    assert.strictEqual(
      found.state,
      "evicted",
      "it was real, and the ring dropped it"
    );
  });

  test("an entry that never existed is absent", function (assert) {
    const found = subject.resolveSubject(subject.entrySubject(999), {
      records: records(10, 11, 12),
      regionKeys: [],
      oldestRetainedSeq: 10,
    });

    assert.strictEqual(
      found.state,
      "absent",
      "ahead of the ring is not the same as behind it"
    );
  });

  /*
   * A merged pair is named by the intent it closed, and the record that carries it
   * is the delivery, whose own sequence is a later, different number. So resolution
   * has to read the claim rather than match the number.
   */
  test("a pair resolves against the record that claims its intent", function (assert) {
    const found = subject.resolveSubject(subject.pairSubject(12), {
      records: [{ seq: 14, kind: "delivered", intentSeq: 12 }],
      regionKeys: [],
      oldestRetainedSeq: 10,
    });

    assert.strictEqual(found.state, "present");
    assert.strictEqual(
      found.record?.seq,
      14,
      "the pair's record is the delivery, not the number the pair is named by"
    );
  });

  // Kind is part of identity for resolution too, not only for the key. An ordinary
  // event that happens to sit at sequence 12 is not the pair that announcement 12
  // opened.
  test("a pair does not resolve against an unrelated entry sharing its number", function (assert) {
    const found = subject.resolveSubject(subject.pairSubject(12), {
      records: records(10, 11, 12),
      regionKeys: [],
      oldestRetainedSeq: 10,
    });

    assert.strictEqual(
      found.state,
      "absent",
      "nothing in the record claims that intent"
    );
  });

  /*
   * A run is selected while it is still being appended to. Its identity is its
   * grouping key and the sequence it STARTED at, never its extent, so a run that
   * grows from three members to sixty is still the same selection.
   */
  test("a run keeps its identity while it grows", function (assert) {
    const selected = subject.runSubject("focusin", 10);
    const early = subject.resolveSubject(selected, {
      records: runRecords("focusin", 10, 10, 11, 12),
      regionKeys: [],
      oldestRetainedSeq: 10,
      newestRetainedSeq: 12,
    });
    const later = subject.resolveSubject(selected, {
      records: runRecords("focusin", 10, 10, 11, 12, 13, 14, 15),
      regionKeys: [],
      oldestRetainedSeq: 10,
      newestRetainedSeq: 15,
    });

    assert.strictEqual(early.state, "present");
    assert.strictEqual(later.state, "present", "still the same run");
    assert.strictEqual(
      subject.subjectKey(selected),
      subject.subjectKey(subject.runSubject("focusin", 10)),
      "and rebuilding the same subject yields the same identity"
    );
  });

  // A run whose head has been evicted but whose tail survives is still there to
  // look at. Reporting it as gone would throw away a selection the reader can
  // still use.
  test("a run partly evicted is still present", function (assert) {
    const found = subject.resolveSubject(subject.runSubject("focusin", 8), {
      records: runRecords("focusin", 8, 10, 11, 12),
      regionKeys: [],
      oldestRetainedSeq: 10,
      newestRetainedSeq: 12,
    });

    assert.strictEqual(found.state, "present");
    assert.strictEqual(
      found.record?.seq,
      10,
      "and resolves to its own oldest surviving member, not to whatever the ring happens to start with"
    );
  });

  /*
   * The fixture above cannot tell a run that finds its own member from one that
   * returns the head of the ring, because there they are the same record. Put an
   * unrelated record in front of the run so the two answers differ.
   */
  test("a run resolves to its own member and not to whatever precedes it", function (assert) {
    const found = subject.resolveSubject(subject.runSubject("focusin", 8), {
      records: [...records(9), ...runRecords("focusin", 8, 10, 11)],
      regionKeys: [],
      oldestRetainedSeq: 9,
      newestRetainedSeq: 11,
    });

    assert.strictEqual(found.state, "present");
    assert.strictEqual(
      found.record?.seq,
      10,
      "the unrelated record at the head of the ring is not a member of this run"
    );
  });

  // Start sequences are unique, so this cannot arise from the timeline as built.
  // It is here to pin that membership is the pair and not the number alone,
  // because matching the number alone would satisfy every other run fixture.
  test("a run does not resolve against a different kind of run starting at the same sequence", function (assert) {
    const found = subject.resolveSubject(subject.runSubject("focusin", 10), {
      records: runRecords("click", 10, 10, 11),
      regionKeys: [],
      oldestRetainedSeq: 10,
      newestRetainedSeq: 11,
    });

    assert.strictEqual(
      found.state,
      "absent",
      "the grouping key is part of what a run is"
    );
  });

  /*
   * Same grouping key, different run. A later burst of the same event kind is not
   * the run that was selected, so a subject whose own members are all gone is
   * evicted even though the record is full of records that look like it.
   */
  test("a run entirely evicted is evicted", function (assert) {
    const found = subject.resolveSubject(subject.runSubject("focusin", 2), {
      records: runRecords("focusin", 40, 40, 41),
      regionKeys: [],
      oldestRetainedSeq: 40,
      newestRetainedSeq: 41,
    });

    assert.strictEqual(found.state, "evicted");
  });

  // Whether the ring reports its newest sequence is incidental. It says nothing
  // about which run a surviving record belongs to, so it cannot be what decides
  // presence.
  test("run presence does not depend on the ring reporting its extent", function (assert) {
    const evicted = {
      records: runRecords("focusin", 40, 40, 41),
      regionKeys: [],
      oldestRetainedSeq: 40,
    };
    const surviving = {
      records: runRecords("focusin", 8, 10, 11),
      regionKeys: [],
      oldestRetainedSeq: 10,
      newestRetainedSeq: 11,
    };

    assert.strictEqual(
      subject.resolveSubject(subject.runSubject("focusin", 2), evicted).state,
      "evicted",
      "no surviving member, with no newest sequence reported"
    );
    assert.strictEqual(
      subject.resolveSubject(subject.runSubject("focusin", 8), surviving).state,
      "present",
      "a surviving member, with a newest sequence reported"
    );
  });

  /*
   * Region identity is a string by design — that is what makes a destroy and
   * recreate detectable as a replacement rather than as an unrelated departure.
   * The selection has to ride on that same string, or reselecting after every
   * re-render becomes the reader's job.
   */
  test("a region subject survives its element being replaced", function (assert) {
    const selected = subject.regionSubject("id:a11y-polite-region");

    assert.strictEqual(
      subject.resolveSubject(selected, {
        records: [],
        regionKeys: ["id:a11y-polite-region"],
      }).state,
      "present",
      "the key is the identity, not the node"
    );
  });

  test("a region that has left is evicted rather than absent", function (assert) {
    const found = subject.resolveSubject(
      subject.regionSubject("id:a11y-polite-region"),
      {
        records: [],
        regionKeys: [],
        knownRegionKeys: ["id:a11y-polite-region"],
      }
    );

    assert.strictEqual(
      found.state,
      "evicted",
      "it was being watched and is not any more"
    );
  });

  // Clearing empties the record but keeps allocating sequence numbers, so a
  // stale selection must not resolve against a later, unrelated entry.
  test("nothing resolves against a cleared record", function (assert) {
    const found = subject.resolveSubject(subject.entrySubject(12), {
      records: [],
      regionKeys: [],
      oldestRetainedSeq: undefined,
    });

    assert.strictEqual(found.state, "absent");
  });

  /*
   * Expanding a run does not move the selection off it. The run row is the thing
   * with `aria-expanded`, so selection has to stay where the control is until a
   * member is deliberately picked — otherwise expanding silently changes what
   * the detail panel is describing.
   */
  test("expanding a run leaves the selection on the run", function (assert) {
    const run = subject.runSubject("focusin", 10);

    assert.strictEqual(
      subject.subjectKey(subject.onRunExpanded(run)),
      subject.subjectKey(run),
      "expansion is a display state, not a selection change"
    );
  });

  test("picking a member of an expanded run selects that member", function (assert) {
    const picked = subject.onRunMemberPicked(
      subject.runSubject("focusin", 10),
      11
    );

    assert.strictEqual(
      subject.subjectKey(picked),
      subject.subjectKey(subject.entrySubject(11)),
      "and from then on it is an ordinary entry selection"
    );
  });
});
