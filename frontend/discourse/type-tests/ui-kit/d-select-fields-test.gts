import DSelect from "discourse/ui-kit/select/d-select";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { selectOption } from "discourse/ui-kit/select/select-engine";

declare const items: Array<{ id: number; name: string; glyph: string }>;
declare const onChange: (value: unknown) => void;

/* Positive: presentation settings are strings. */
selectOption(items[0]!, { label: "Ripe", icon: "lemon" });
selectOption(items[0]!, { label: null, icon: null });

/* Negative: they are never anything else. */
// @ts-expect-error - a label is a string
selectOption(items[0]!, { label: 3 });
// @ts-expect-error - an icon is an icon name
selectOption(items[0]!, { icon: { id: "lemon" } });

/* Field arguments name record fields. */
const Test = <template>
  <DSelect
    @descriptionField="detail"
    @iconField="glyph"
    @onChange={{onChange}}
    @options={{items}}
  />
  <DSelectList
    @descriptionField="detail"
    @iconField="glyph"
    @onChange={{onChange}}
    @options={{items}}
  />

  {{! @glint-expect-error - a field argument is a field name }}
  <DSelect @iconField={{3}} @onChange={{onChange}} @options={{items}} />
</template>;

export default Test;
