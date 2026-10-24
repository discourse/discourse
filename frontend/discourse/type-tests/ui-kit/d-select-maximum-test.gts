import DSelect from "discourse/ui-kit/select/d-select";
import DSelectList from "discourse/ui-kit/select/d-select-list";

declare const items: Array<{ id: number; name: string }>;
declare const onChange: (value: unknown) => void;

// `false` means "no cap" on both components; a number stays a cap. Each valid usage must
// compile, and the string cap must be flagged.
const Test = <template>
  <DSelect
    @items={{items}}
    @maximum={{false}}
    @multiple={{true}}
    @onChange={{onChange}}
  />
  <DSelect
    @items={{items}}
    @maximum={{3}}
    @multiple={{true}}
    @onChange={{onChange}}
  />
  <DSelectList @items={{items}} @maximum={{false}} @onChange={{onChange}} />

  {{! @glint-expect-error - @maximum is a number or false, not a string }}
  <DSelect @items={{items}} @maximum="3" @onChange={{onChange}} />
</template>;

export default Test;
