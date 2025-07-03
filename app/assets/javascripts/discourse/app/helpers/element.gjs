import ClassicComponent from "@ember/component";

const empty = <template>
  {{! template-lint-disable no-yield-only}}{{yield}}
</template>;
const shortcuts = {
  div: <template>
    <div ...attributes>{{yield}}</div>
  </template>,
  span: <template>
    <span ...attributes>{{yield}}</span>
  </template>,
  form: <template>
    <form ...attributes>{{yield}}</form>
  </template>,
  a: <template>
    <a ...attributes>{{yield}}</a>
  </template>,
  button: <template>
    <button ...attributes>{{yield}}</button>
  </template>,
  td: <template>
    <td ...attributes>{{yield}}</td>
  </template>,
  aside: <template>
    <aside ...attributes>{{yield}}</aside>
  </template>,
};

/**
 * Returns a wrapper component with the given tagname, or an empty wrapper for an empty string.
 * Similar to the reference implementation of RFC389, with higher-performance shortcuts for common elements.
 *
 * Can be used directly in a template:
 *
 * ```hbs
 * {{#let (element @tagName) as |Wrapper|}}
 *   <Wrapper class="pt-10 pb-10 ps-20 box-shadow" ...attributes>
 *     Content
 *   </Wrapper>
 * {{/let}}
 * ```
 *
 * Or in js:
 *
 * ```gjs
 * class MyComponent {
 *   get wrapper(){
 *     return element(this.args.tagName);
 *   }
 *
 *   <template>
 *     <this.wrapper>
 *       Content
 *     </this.wrapper>
 *   </template>
 * }
 * ```
 */
export default function element(tagName) {
  if (typeof tagName !== "string") {
    throw new Error(
      `element helper only accepts string literals, you passed ${tagName}`
    );
  }

  if (tagName === null || tagName === undefined) {
    return null;
  } else if (tagName === "") {
    return empty;
  } else if (shortcuts[tagName]) {
    return shortcuts[tagName];
  } else {
    return <template>
      <ClassicComponent
        @tagName={{tagName}}
        ...attributes
      >{{yield}}</ClassicComponent>
    </template>;
  }
}
