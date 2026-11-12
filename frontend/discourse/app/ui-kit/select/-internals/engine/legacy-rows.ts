import type SelectArgsView from "discourse/ui-kit/select/-internals/engine/select-args";
import {
  isSelectOption,
  type SelectOption,
  selectOption,
  type SelectOptionSettings,
} from "discourse/ui-kit/select/-internals/engine/select-option";
import type {
  SelectControl,
  SelectRecord,
} from "discourse/ui-kit/select/select-engine";

/** A select-kit row's own `onSelect`, called with the row as `this`. */
export type LegacyRowAction = (
  this: SelectRecord,
  ...args: unknown[]
) => unknown;

/** Turns a row's legacy `onSelect` into the action its option runs. */
export type LegacyActionAdapter = (
  legacy: LegacyRowAction,
  row: SelectRecord
) => (control: SelectControl, record: SelectRecord) => void;

/** Calls the legacy action as select-kit did, with the row as `this`. */
const callOnRow: LegacyActionAdapter = (legacy, row) => (control, record) =>
  void legacy.call(row, control, record);

/**
 * The settings a select-kit row expressed through its own fields. Legacy code wrote these rows
 * for select-kit, where the fields are behaviour, so they are read here and nowhere else.
 */
function legacySettings(
  row: SelectRecord,
  adaptAction: LegacyActionAdapter
): SelectOptionSettings {
  const settings: SelectOptionSettings = {};
  if (typeof row.onSelect === "function") {
    settings.onSelect = adaptAction(
      row.onSelect as LegacyRowAction,
      row
    ) as SelectOptionSettings["onSelect"];
  }
  if (row.disabled) {
    settings.disabled = true;
  }
  if (row.sticky) {
    settings.position = "sticky";
  }
  if (typeof row.description === "string" && row.description) {
    settings.description = row.description;
  }
  return settings;
}

/**
 * Maps rows a record-level step returned back to options. A record the step kept is its own
 * option again, found by identity, which is unambiguous because one record object is one
 * option. A row the step made was written for select-kit, so its legacy fields become
 * settings; a copy whose value matches exactly one input keeps that input's settings, with its
 * own fields on top.
 *
 * @param inputs - The options the step was given, as records.
 * @param outputs - What the step returned.
 * @param args - The engine's args, for value keys.
 * @param adaptAction - Turns a row's legacy `onSelect` into its option's action; by default it
 *   is called with the row as `this` and the control as its first argument.
 */
export function optionsFromLegacyRows(
  inputs: readonly SelectOption[],
  outputs: readonly unknown[],
  args: SelectArgsView,
  adaptAction: LegacyActionAdapter = callOnRow
): SelectOption[] {
  const byRecord = new Map<object, SelectOption>();
  const byKey = new Map<string, SelectOption | null>();
  for (const option of inputs) {
    byRecord.set(option.record, option);
    const key = args.valueKey(args.recordValue(option.record));
    if (key != null) {
      byKey.set(key, byKey.has(key) ? null : option);
    }
  }
  return outputs.map((output) => {
    if (isSelectOption(output)) {
      return output as SelectOption;
    }
    const row = output as SelectRecord;
    const kept = byRecord.get(row);
    if (kept) {
      return kept;
    }
    const key = args.valueKey(args.recordValue(row));
    const source = key == null ? undefined : byKey.get(key);
    const settings = legacySettings(row, adaptAction);
    return source
      ? selectOption(row).with(source.settings).with(settings)
      : selectOption(row, settings);
  });
}
