import { makeArray } from "discourse/lib/helpers";
import type Topic from "discourse/models/topic";
import {
  renderSelectText,
  type SelectItem,
  type SelectItemId,
  type SelectResolvedOptions,
  type SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** Receives a topic picker's held ids and topics: arrays when it holds several, else one or `null`. */
export type TopicChangeHandler = (
  value: number[] | number | null,
  topics: Topic[] | Topic | null
) => void;

/** The stand-in for a held id no topic answers for, named by the `unresolved` text. */
export function unresolvedTopic(
  value: SelectItemId,
  options: SelectResolvedOptions
): SelectItem {
  return {
    id: value,
    title: renderSelectText(options, "unresolved", { id: value }),
  };
}

/** Hands a change on with numeric ids, in the shape the picker holds. */
export function emitTopicChange(
  onChange: TopicChangeHandler | undefined,
  multiple: boolean,
  value: SelectValue,
  items: SelectItem | SelectItem[] | null
): void {
  if (multiple) {
    onChange?.(
      makeArray(value as number | number[]).map(Number),
      makeArray(items) as unknown as Topic[]
    );
    return;
  }
  onChange?.(
    value == null ? null : Number(value),
    (items as unknown as Topic | null) ?? null
  );
}
