export interface EntrySubject {
  readonly kind: "entry";
  readonly seq: number;
}

export interface PairSubject {
  readonly kind: "pair";
  readonly intentSeq: number;
}

export interface RunSubject {
  readonly kind: "run";
  readonly groupingKey: string;
  readonly startedAtSeq: number;
}

export interface RegionSubject {
  readonly kind: "region";
  readonly regionKey: string;
}

export type SelectedSubject =
  | EntrySubject
  | PairSubject
  | RunSubject
  | RegionSubject;

export interface SubjectRecord {
  readonly seq: number;
  readonly intentSeq?: number;
  readonly groupingKey?: string;
  readonly runStartedAtSeq?: number;
}

export interface SubjectContext<
  RecordType extends SubjectRecord = SubjectRecord,
> {
  readonly records: readonly RecordType[];
  readonly regionKeys: readonly string[];
  readonly oldestRetainedSeq?: number;
  readonly newestRetainedSeq?: number;
  readonly knownRegionKeys?: readonly string[];
}

export type SubjectState = "present" | "evicted" | "absent";

export interface SubjectResolution<
  RecordType extends SubjectRecord = SubjectRecord,
> {
  readonly state: SubjectState;
  readonly record?: RecordType;
}

export function entrySubject(seq: number): EntrySubject {
  return { kind: "entry", seq };
}

export function pairSubject(intentSeq: number): PairSubject {
  return { kind: "pair", intentSeq };
}

export function runSubject(
  groupingKey: string,
  startedAtSeq: number
): RunSubject {
  return { kind: "run", groupingKey, startedAtSeq };
}

export function regionSubject(regionKey: string): RegionSubject {
  return { kind: "region", regionKey };
}

export function subjectKey(subject: SelectedSubject): string {
  switch (subject.kind) {
    case "entry":
      return JSON.stringify([subject.kind, subject.seq]);
    case "pair":
      return JSON.stringify([subject.kind, subject.intentSeq]);
    case "run":
      return JSON.stringify([
        subject.kind,
        subject.groupingKey,
        subject.startedAtSeq,
      ]);
    case "region":
      return JSON.stringify([subject.kind, subject.regionKey]);
  }
}

export function resolveSubject<RecordType extends SubjectRecord>(
  subject: SelectedSubject,
  context: SubjectContext<RecordType>
): SubjectResolution<RecordType> {
  if (subject.kind === "region") {
    if (context.regionKeys.includes(subject.regionKey)) {
      return { state: "present" };
    }

    return {
      state: context.knownRegionKeys?.includes(subject.regionKey)
        ? "evicted"
        : "absent",
    };
  }

  if (subject.kind === "run") {
    const record = context.records.find(
      ({ groupingKey, runStartedAtSeq }) =>
        groupingKey === subject.groupingKey &&
        runStartedAtSeq === subject.startedAtSeq
    );
    if (record) {
      return { state: "present", record };
    }

    if (
      context.oldestRetainedSeq !== undefined &&
      subject.startedAtSeq < context.oldestRetainedSeq
    ) {
      return { state: "evicted" };
    }

    return { state: "absent" };
  }

  const seq = subject.kind === "entry" ? subject.seq : subject.intentSeq;
  const record = context.records.find(
    subject.kind === "entry"
      ? (candidate) => candidate.seq === seq
      : (candidate) => candidate.intentSeq === seq
  );

  if (record) {
    return { state: "present", record };
  }

  return {
    state:
      context.oldestRetainedSeq !== undefined && seq < context.oldestRetainedSeq
        ? "evicted"
        : "absent",
  };
}

export function onRunExpanded(run: RunSubject): RunSubject {
  return run;
}

export function onRunMemberPicked(_run: RunSubject, seq: number): EntrySubject {
  return entrySubject(seq);
}
