import DSelect from "discourse/ui-kit/select/d-select";
import {
  renderSelectText,
  type SelectOption,
  selectOption,
} from "discourse/ui-kit/select/select-engine";

declare const items: Array<{ id: number; name: string; group: string }>;

const textHeader = (key: unknown) => String(key);
const actionFooter = (key: unknown, options: readonly SelectOption[]) =>
  selectOption(
    { id: `all:${String(key)}`, name: `All ${String(key)}` },
    { onSelect: () => options.length }
  );
const bareFooter = (key: unknown) => ({
  id: `all:${String(key)}`,
  name: `All ${String(key)}`,
  onSelect: () => undefined,
});
const nothing = () => null;
const count = () => 3;

// A builder returns text, an action option, or nothing, for a header and a footer alike; the
// group blocks yield the boundary's record, the resolved config and the group.
const Test = <template>
  <DSelect
    @groupBy="group"
    @groupFooter={{actionFooter}}
    @groupHeader={{textHeader}}
    @options={{items}}
  >
    <:groupHeader as |record config group|>
      {{if group.action "action" "text"}}
      {{if group.key "keyed"}}
      {{if record.label "labelled"}}
      {{renderSelectText config "placeholder"}}
    </:groupHeader>
    <:groupFooter as |record config group|>
      {{if group.action "action" "text"}}
      {{renderSelectText config "placeholder"}}
    </:groupFooter>
  </DSelect>
  <DSelect
    @groupBy="group"
    @groupFooter={{textHeader}}
    @groupHeader={{nothing}}
    @options={{items}}
  />

  <DSelect
    @groupBy="group"
    @groupDividers={{false}}
    @groupFooter={{actionFooter}}
    @options={{items}}
  />

  {{! @glint-expect-error - groupDividers is a boolean }}
  <DSelect @groupBy="group" @groupDividers="no" @options={{items}} />

  {{! @glint-expect-error - a builder returns text, an action option or nothing }}
  <DSelect @groupBy="group" @groupFooter={{count}} @options={{items}} />

  {{! @glint-expect-error - a record with an onSelect field is not an action option }}
  <DSelect @groupBy="group" @groupFooter={{bareFooter}} @options={{items}} />
</template>;

export default Test;
