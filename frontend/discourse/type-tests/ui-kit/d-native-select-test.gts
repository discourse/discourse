// Positive type assertions for DNativeSelect's value typing: every invocation below
// must compile. Keep this file free of Glint error directives, because one would
// suppress reporting for the rest of the file.
import DNativeSelect from "discourse/ui-kit/d-native-select";

declare function onChange(value: string | null): void;

const Positives = <template>
  {{! A string, a number, or none selects the matching option }}
  <DNativeSelect @onChange={{onChange}} @value="foo" as |s|>
    <s.Option @value="foo">Foo</s.Option>
  </DNativeSelect>
  <DNativeSelect @onChange={{onChange}} @value={{30}} as |s|>
    <s.Option @value={{30}}>Thirty</s.Option>
  </DNativeSelect>
  <DNativeSelect @onChange={{onChange}} @value={{null}} as |s|>
    <s.Option>None</s.Option>
  </DNativeSelect>

  {{! A boolean is a value of its own, and false is not none }}
  <DNativeSelect @onChange={{onChange}} @value={{false}} as |s|>
    <s.Option @value={{false}}>No</s.Option>
    <s.Option @value={{true}}>Yes</s.Option>
  </DNativeSelect>
</template>;

export default Positives;
