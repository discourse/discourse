import { expectTypeOf } from "expect-type";
import type {
  SelectChangeContext,
  SelectCustomizationSpec,
  SelectOptionAttributesContext,
} from "discourse/ui-kit/select/-internals/engine/customizations";
import {
  type SelectControl,
  type SelectOption,
  selectOption,
  type SelectOptionLike,
  type SelectRecord,
} from "discourse/ui-kit/select/select-engine";

interface Fruit {
  id: number;
  name: string;
}

declare const fruit: Fruit;

/* Positive: an option keeps its record's type, and its action receives that record. */
const plain = selectOption(fruit);
expectTypeOf(plain).toEqualTypeOf<SelectOption<Fruit>>();
expectTypeOf(plain.record).toEqualTypeOf<Fruit>();

const action = selectOption(fruit, {
  position: "sticky",
  divider: "before",
  description: "Ripe",
  onSelect: (control, record) => {
    expectTypeOf(control).toEqualTypeOf<SelectControl>();
    expectTypeOf(record).toEqualTypeOf<Fruit>();
  },
});
expectTypeOf(action.with({ description: null })).toEqualTypeOf<
  SelectOption<Fruit>
>();

/* Positive: a list takes records and options alike. */
expectTypeOf<[Fruit, SelectOption<Fruit>]>().items.toMatchTypeOf<
  SelectOptionLike<Fruit>
>();

/* Negative: settings are a closed set with closed values. */
// @ts-expect-error - "sticky" is a position, not a setting
selectOption(fruit, { sticky: true });
// @ts-expect-error - a position is "sticky" or "end"
selectOption(fruit, { position: "top" });
// @ts-expect-error - a divider is "before" or "after"
selectOption(fruit, { divider: "between" });

/* Negative: an option is not a record, so a forgotten `.record` does not compile. */
// @ts-expect-error - read option.record
const forgotten: SelectRecord = plain;

/* Positive: content steps get options, the attributes step gets the option and its record, and a
   change hands back records. */
type ContentStep = Parameters<SelectCustomizationSpec["content"]>[0];
expectTypeOf<Parameters<ContentStep>[0]>().toEqualTypeOf<SelectOption[]>();
expectTypeOf<
  SelectOptionAttributesContext["option"]
>().toEqualTypeOf<SelectOption>();
expectTypeOf<
  SelectOptionAttributesContext["record"]
>().toEqualTypeOf<SelectRecord>();
expectTypeOf<SelectChangeContext["records"]>().toEqualTypeOf<
  SelectRecord | SelectRecord[] | null
>();

export { forgotten };
