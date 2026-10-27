import DSelect from "discourse/ui-kit/select/d-select";
import type { SelectItem } from "discourse/ui-kit/select/select-engine";

declare const items: Array<{ id: number; name: string; group: string }>;

const textHeader = (key: unknown) => String(key);
const actionFooter = (key: unknown, rows: readonly SelectItem[]) => ({
  id: `all:${String(key)}`,
  name: `All ${String(key)}`,
  onSelect: () => rows.length,
});
const nothing = () => null;
const count = () => 3;

// A builder returns text, an action row, or nothing, for a header and a footer alike; the
// group blocks yield the row's item and the resolved options.
const Test = <template>
  <DSelect
    @groupBy="group"
    @groupFooter={{actionFooter}}
    @groupHeader={{textHeader}}
    @items={{items}}
  >
    <:groupHeader as |item options|>
      {{if item.onSelect "action" "text"}}
      {{options.placeholder}}
    </:groupHeader>
    <:groupFooter as |item options|>
      {{if item.onSelect "action" "text"}}
      {{options.placeholder}}
    </:groupFooter>
  </DSelect>
  <DSelect
    @groupBy="group"
    @groupFooter={{textHeader}}
    @groupHeader={{nothing}}
    @items={{items}}
  />

  {{! @glint-expect-error - a builder returns text, an action row or nothing }}
  <DSelect @groupBy="group" @groupFooter={{count}} @items={{items}} />
</template>;

export default Test;
