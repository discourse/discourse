import DSelect from "discourse/ui-kit/select/d-select";
import DSelectList from "discourse/ui-kit/select/d-select-list";

declare const items: Array<{ id: number; name: string }>;
declare const onChange: (value: unknown) => void;

// `false` means "no cap" on both components; a number stays a cap. Each valid usage must
// compile, and the string cap must be flagged.
const Test = <template>
  <DSelect
    @maximum={{false}}
    @multiple={{true}}
    @onChange={{onChange}}
    @options={{items}}
  />
  <DSelect
    @maximum={{3}}
    @multiple={{true}}
    @onChange={{onChange}}
    @options={{items}}
  />
  <DSelectList @maximum={{false}} @onChange={{onChange}} @options={{items}} />

  {{! @glint-expect-error - @maximum is a number or false, not a string }}
  <DSelect @maximum="3" @onChange={{onChange}} @options={{items}} />
</template>;

export default Test;
