import { makeArray } from "discourse/lib/helpers";
import type Topic from "discourse/models/topic";
import {
  renderSelectText,
  type SelectConfig,
  type SelectId,
  type SelectRecord,
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** Receives a topic picker's held ids and topics: arrays when it holds several, else one or `null`. */
export type TopicChangeHandler = (
  value: number[] | number | null,
  topics: Topic[] | Topic | null
) => void;

/** The stand-in for a held id no topic answers for, named by the `unresolved` text. */
export function unresolvedTopic(
  value: SelectId,
  config: SelectConfig
): SelectRecord {
  return {
    id: value,
    title: renderSelectText(config, "unresolved", { id: value }),
  };
}

/** Hands a change on with numeric ids, in the shape the picker holds. */
export function emitTopicChange(
  onChange: TopicChangeHandler | undefined,
  multiple: boolean,
  value: SelectValue,
  records: SelectRecord | SelectRecord[] | null
): void {
  if (multiple) {
    onChange?.(
      makeArray(value as number | number[]).map(Number),
      makeArray(records) as unknown as Topic[]
    );
    return;
  }
  onChange?.(
    value == null ? null : Number(value),
    (records as unknown as Topic | null) ?? null
  );
}
