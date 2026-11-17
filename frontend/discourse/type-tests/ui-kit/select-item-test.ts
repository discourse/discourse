import { expectTypeOf } from "expect-type";
import type { SelectItem } from "discourse/ui-kit/select/-internals/engine/select-item";
import {
  entryRecord,
  recordOf,
  type SelectOption,
  selectOption,
} from "discourse/ui-kit/select/-internals/engine/select-option";
import type { SelectRecord } from "discourse/ui-kit/select/select-engine";

declare const item: SelectItem;

// An item handed back as an entry stands for its record, never for itself.
expectTypeOf(recordOf(item)).toEqualTypeOf<SelectRecord>();
expectTypeOf(entryRecord(item)).toEqualTypeOf<SelectRecord>();
expectTypeOf(selectOption(item)).toEqualTypeOf<SelectOption<SelectRecord>>();

// A plain record keeps its own type.
const fruit = { id: 1, name: "Pear" };
expectTypeOf(recordOf(fruit)).toEqualTypeOf<{ id: number; name: string }>();
expectTypeOf(selectOption(fruit)).toEqualTypeOf<
  SelectOption<{ id: number; name: string }>
>();
