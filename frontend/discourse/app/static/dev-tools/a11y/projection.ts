import {
  type Finding,
  findingSubjectEquivalenceKey,
} from "discourse/static/dev-tools/a11y/findings";
import type { TimelineEntry } from "discourse/static/dev-tools/a11y/instrumentation";
import {
  entrySubject,
  pairSubject,
  regionSubject,
  runSubject,
  SelectedSubject,
  subjectKey,
  SubjectRecord,
} from "discourse/static/dev-tools/a11y/subject";

/**
 * The timeline as rows, which is not the same shape as the timeline as records.
 *
 * A record is what happened. A row is what a reader looks at, and the two differ
 * in three ways the panel has to reconcile: an announcement and the delivery that
 * answered it are one row spanning two records, a burst of the same event is one
 * row standing for many, and third-party live-region churn is one row standing for
 * a great deal of noise nobody asked about.
 *
 * Projection never changes what was recorded. The records stay exactly as they
 * were captured, and every row points back at the sequence numbers it stands for.
 */

export type RowKind = "atomic" | "pair" | "run" | "churn";

/** What the row's rail carries, and the only thing it carries. */
export type RowSeverity = "danger" | "highlight" | "none";

export interface Row {
  /** The subject's identity, so selection and projection cannot disagree. */
  readonly id: string;
  readonly kind: RowKind;
  readonly subject: SelectedSubject;
  readonly severity: RowSeverity;
  /** Runs and churn recede to the noise floor; nothing else does. */
  readonly quiet: boolean;
  /** The sequences this row stands for, oldest first. */
  readonly members: readonly number[];
  readonly seqLabel: string;
  /** How many records a run or churn group collapsed. */
  readonly count?: number;
  /** Time since the row before this one, never a sum over members. */
  readonly elapsedMs?: number;
  /** A pair only: how long the announcement took to arrive. */
  readonly latencyMs?: number;
  readonly findings: readonly Finding[];
}

export interface Projection {
  readonly rows: readonly Row[];
  /**
   * The same records, annotated with the run each belongs to.
   *
   * `resolveSubject` decides whether a selected run is still present by looking
   * for a surviving member, so a record has to carry the run it belongs to — and
   * only the projection knows that.
   */
  readonly records: readonly SubjectRecord[];
}

interface Candidate {
  readonly entries: readonly TimelineEntry[];
  readonly groupingKey?: string;
  readonly pairIntentSeq?: number;
}

const LIVE_REGION_LIFECYCLE_LABELS = new Set([
  "live region joined",
  "live region left",
  "live region replaced",
  "live region cleared",
]);

export function project(entries: readonly TimelineEntry[]): Projection {
  const coalesced = coalesceFocusChanges(entries);
  const paired = pairAnnouncements(coalesced);
  const { rows, runs } = groupCandidates(paired);
  const runBySeq = new Map(
    runs.flatMap(({ groupingKey, startedAtSeq, members }) =>
      members.map((seq) => [seq, { groupingKey, startedAtSeq }] as const)
    )
  );

  return {
    rows,
    records: entries.map((entry) => {
      const run = runBySeq.get(entry.seq);
      return run
        ? {
            ...entry,
            groupingKey: run.groupingKey,
            runStartedAtSeq: run.startedAtSeq,
          }
        : { ...entry };
    }),
  };
}

/** Two findings are the same finding when their rule and parameters agree. */
export function findingEquivalenceKey(recorded: Finding): string {
  return JSON.stringify([
    recorded.id,
    Object.entries(recorded.params).sort(([left], [right]) =>
      left.localeCompare(right)
    ),
  ]);
}

function coalesceFocusChanges(entries: readonly TimelineEntry[]): Candidate[] {
  const candidates: Candidate[] = [];

  for (let index = 0; index < entries.length; index++) {
    const entry = entries[index];
    const nextEntry = entries[index + 1];

    if (
      entry.kind === "event" &&
      entry.label === "keydown" &&
      nextEntry?.kind === "event" &&
      nextEntry.label === "focusin"
    ) {
      candidates.push({
        entries: [entry, nextEntry],
        groupingKey: entry.label,
      });
      index++;
    } else {
      candidates.push({ entries: [entry], groupingKey: entry.label });
    }
  }

  return candidates;
}

function pairAnnouncements(candidates: readonly Candidate[]): Candidate[] {
  const intentIndexes = new Map<number, number>();
  const replacements = new Map<number, Candidate>();
  const removed = new Set<number>();

  for (const [index, candidate] of candidates.entries()) {
    const [entry] = candidate.entries;
    if (candidate.entries.length === 1 && entry.kind === "intent") {
      intentIndexes.set(entry.seq, index);
    }
  }

  for (const [index, candidate] of candidates.entries()) {
    const [entry] = candidate.entries;
    if (
      candidate.entries.length !== 1 ||
      entry.kind !== "delivered" ||
      entry.intentSeq === undefined
    ) {
      continue;
    }

    const intentIndex = intentIndexes.get(entry.intentSeq);
    if (intentIndex === undefined || replacements.has(intentIndex)) {
      replacements.set(index, {
        entries: [entry],
        pairIntentSeq: entry.intentSeq,
      });
      continue;
    }

    replacements.set(intentIndex, {
      entries: [...candidates[intentIndex].entries, entry],
      pairIntentSeq: entry.intentSeq,
    });
    removed.add(index);
  }

  return candidates.flatMap((candidate, index) =>
    removed.has(index) ? [] : [replacements.get(index) ?? candidate]
  );
}

function groupCandidates(candidates: readonly Candidate[]): {
  rows: Row[];
  runs: Array<{
    groupingKey: string;
    startedAtSeq: number;
    members: readonly number[];
  }>;
} {
  const rows: Row[] = [];
  const runs: Array<{
    groupingKey: string;
    startedAtSeq: number;
    members: readonly number[];
  }> = [];

  for (let index = 0; index < candidates.length; ) {
    const candidate = candidates[index];
    const regionKey = lifecycleRegionKey(candidate);
    const candidateFindingKey = churnFindingEquivalenceKey(candidate);
    if (regionKey && candidateFindingKey !== undefined) {
      const group = [candidate];
      let groupFindingKey = candidateFindingKey;
      while (true) {
        const nextCandidate = candidates[index + group.length];
        if (lifecycleRegionKey(nextCandidate) !== regionKey) {
          break;
        }

        const nextFindingKey = churnFindingEquivalenceKey(nextCandidate);
        if (
          nextFindingKey === undefined ||
          (groupFindingKey !== null &&
            nextFindingKey !== null &&
            nextFindingKey !== groupFindingKey)
        ) {
          break;
        }

        group.push(nextCandidate);
        if (nextFindingKey !== null) {
          groupFindingKey = nextFindingKey;
        }
      }

      if (group.length > 1) {
        rows.push(churnRow(group, regionKey));
        index += group.length;
        continue;
      }
    }

    if (
      candidate.groupingKey &&
      !regionKey &&
      !candidate.pairIntentSeq &&
      !candidateCarriesFinding(candidate)
    ) {
      const group = [candidate];
      while (
        candidates[index + group.length]?.groupingKey ===
          candidate.groupingKey &&
        !lifecycleRegionKey(candidates[index + group.length]) &&
        !candidates[index + group.length]?.pairIntentSeq &&
        !candidateCarriesFinding(candidates[index + group.length])
      ) {
        group.push(candidates[index + group.length]);
      }

      if (group.length > 1) {
        const projectedRow = runRow(group, candidate.groupingKey);
        rows.push(projectedRow);
        runs.push({
          groupingKey: candidate.groupingKey,
          startedAtSeq: projectedRow.members[0],
          members: projectedRow.members,
        });
        index += group.length;
        continue;
      }
    }

    rows.push(candidateRow(candidate));
    index++;
  }

  return { rows, runs };
}

function candidateRow(candidate: Candidate): Row {
  if (candidate.pairIntentSeq !== undefined) {
    const subject = pairSubject(candidate.pairIntentSeq);
    const intent = candidate.entries.find(({ kind }) => kind === "intent");
    const delivery = candidate.entries.find(({ kind }) => kind === "delivered");

    return row({
      kind: "pair",
      subject,
      entries: candidate.entries,
      seqLabel:
        intent && delivery!.seq === intent.seq + 1
          ? rangeLabel(candidate.entries)
          : `${intent ? `#${intent.seq} ` : ""}\u2192 #${delivery!.seq}`,
      elapsedMs: (intent ?? delivery)?.elapsedMs,
      latencyMs: delivery?.latencyMs,
    });
  }

  const subject = entrySubject(candidate.entries[0].seq);
  return row({
    kind: "atomic",
    subject,
    entries: candidate.entries,
    seqLabel:
      candidate.entries.length === 1
        ? `#${candidate.entries[0].seq}`
        : rangeLabel(candidate.entries),
    elapsedMs: candidate.entries[0].elapsedMs,
  });
}

function runRow(candidates: readonly Candidate[], groupingKey: string): Row {
  const entries = candidates.flatMap((candidate) => candidate.entries);
  const subject = runSubject(groupingKey, entries[0].seq);
  return row({
    kind: "run",
    subject,
    entries,
    seqLabel: rangeLabel(entries),
    elapsedMs: entries[0].elapsedMs,
    count: entries.length,
  });
}

function churnRow(candidates: readonly Candidate[], regionKey: string): Row {
  const entries = candidates.flatMap((candidate) => candidate.entries);
  const subject = regionSubject(regionKey);
  return row({
    kind: "churn",
    subject,
    entries,
    seqLabel: rangeLabel(entries),
    elapsedMs: entries[0].elapsedMs,
    count: entries.length,
  });
}

function row({
  kind,
  subject,
  entries,
  seqLabel,
  elapsedMs,
  count,
  latencyMs,
}: {
  kind: RowKind;
  subject: SelectedSubject;
  entries: readonly TimelineEntry[];
  seqLabel: string;
  elapsedMs?: number;
  count?: number;
  latencyMs?: number;
}): Row {
  const findings = distinctFindings(
    entries,
    kind === "churn"
      ? (recorded) =>
          findingSubjectEquivalenceKey(recorded) ??
          findingEquivalenceKey(recorded)
      : findingEquivalenceKey
  );
  return {
    id: subjectKey(subject),
    kind,
    subject,
    severity: severityFor(findings),
    quiet: kind === "run" || kind === "churn",
    members: entries.map(({ seq }) => seq),
    seqLabel,
    ...(count !== undefined ? { count } : {}),
    ...(elapsedMs !== undefined ? { elapsedMs } : {}),
    ...(latencyMs !== undefined ? { latencyMs } : {}),
    findings,
  };
}

function distinctFindings(
  entries: readonly TimelineEntry[],
  equivalenceKey: (recorded: Finding) => string
): Finding[] {
  const seen = new Set<string>();
  return entries.flatMap(({ findings }) =>
    findings.filter((recorded) => {
      const key = equivalenceKey(recorded);
      if (seen.has(key)) {
        return false;
      }

      seen.add(key);
      return true;
    })
  );
}

function severityFor(findings: readonly Finding[]): RowSeverity {
  if (findings.some(({ tier }) => tier === "broken")) {
    return "danger";
  }
  if (findings.some(({ tier }) => tier === "fragile")) {
    return "highlight";
  }
  return "none";
}

function lifecycleRegionKey(
  candidate: Candidate | undefined
): string | undefined {
  if (!candidate || candidate.entries.length !== 1) {
    return undefined;
  }

  const [entry] = candidate.entries;
  return LIVE_REGION_LIFECYCLE_LABELS.has(entry.label)
    ? entry.regionKey
    : undefined;
}

function candidateCarriesFinding(candidate: Candidate | undefined): boolean {
  return (
    candidate?.entries.some(({ findings }) => findings.length > 0) ?? false
  );
}

/** Clean churn is neutral; undeclared finding subjects conservatively block it. */
function churnFindingEquivalenceKey(
  candidate: Candidate
): string | null | undefined {
  const findings = candidate.entries.flatMap((entry) => entry.findings);
  if (findings.length === 0) {
    return null;
  }

  const keys = findings.map(findingSubjectEquivalenceKey);
  if (keys.some((key) => key === undefined)) {
    return;
  }

  return JSON.stringify([...new Set(keys)].sort());
}

function rangeLabel(entries: readonly TimelineEntry[]): string {
  return `#${entries[0].seq}\u2013${entries.at(-1)!.seq}`;
}
