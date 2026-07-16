import dElement from "discourse/ui-kit/helpers/d-element";

declare const condition: boolean;
declare const dynamicTag: string;

// A single known tag yields a wrapper typed with that exact element.
const Anchor = dElement("a");
const Button = dElement("button");

// A runtime-chosen union of known tags yields a wrapper that accepts any
// attribute valid on either arm.
const AnchorOrButton = dElement(condition ? "a" : "button");

// An empty string (pass-through) and a dynamic tag name fall back to a generic
// wrapper that only accepts global attributes.
const Passthrough = dElement("");
const Dynamic = dElement(dynamicTag);

// Asserts the signature keeps per-tag attribute checking. Each valid usage must
// compile; each invalid usage must be flagged (a missing error fails
// pnpm lint:types via the glint-expect-error directives).
const Test = <template>
  {{! Per-tag attributes are accepted on the matching element }}
  <Anchor href="/x">ok</Anchor>
  <Button type="submit" disabled={{true}}>ok</Button>

  {{! A union wrapper accepts attributes valid on either arm }}
  <AnchorOrButton href="/x" type="submit" disabled={{true}}>ok</AnchorOrButton>

  {{! The pass-through and dynamic fallbacks accept global attributes }}
  <Passthrough class="c">ok</Passthrough>
  <Dynamic class="c" data-x="y">ok</Dynamic>

  {{! @glint-expect-error - disabled is button-only, not valid on an anchor }}
  <Anchor disabled={{true}}>bad</Anchor>

  {{! @glint-expect-error - href is anchor-only, not valid on a button }}
  <Button href="/x">bad</Button>

  {{! @glint-expect-error - an unknown attribute is rejected even on a union }}
  <AnchorOrButton totallybogusattr="x">bad</AnchorOrButton>
</template>;

export default Test;
