import { expectTypeOf } from "expect-type";
import type { SelectResolvedOption } from "discourse/ui-kit/select/-internals/engine/resolved-option";
import {
  entryRecord,
  recordOf,
  type SelectOption,
  selectOption,
} from "discourse/ui-kit/select/-internals/engine/select-option";
import type { SelectRecord } from "discourse/ui-kit/select/select-engine";

declare const item: SelectResolvedOption;

// A resolved option handed back as an entry stands for its record, never for itself.
expectTypeOf(recordOf(item)).toEqualTypeOf<SelectRecord>();
expectTypeOf(entryRecord(item)).toEqualTypeOf<SelectRecord>();
expectTypeOf(selectOption(item)).toEqualTypeOf<SelectOption<SelectRecord>>();

// A plain record keeps its own type.
const fruit = { id: 1, name: "Pear" };
expectTypeOf(recordOf(fruit)).toEqualTypeOf<{ id: number; name: string }>();
expectTypeOf(selectOption(fruit)).toEqualTypeOf<
  SelectOption<{ id: number; name: string }>
>();
