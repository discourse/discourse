/* eslint-disable ember/no-classic-components */
import ClassicComponent from "@ember/component";
import type { TemplateOnlyComponent } from "@ember/component/template-only";
import type { ComponentLike } from "@glint/template";

// The tag names that have a dedicated, higher-performance shortcut wrapper.
type ShortcutTag = "div" | "span" | "form" | "a" | "button" | "td" | "aside";

// A wrapper component for a single known tag, typed with the matching element so
// that `...attributes` and named attributes are checked against that element.
type ElementWrapper<T extends keyof HTMLElementTagNameMap> =
  TemplateOnlyComponent<{
    Element: HTMLElementTagNameMap[T];
    Blocks: { default: [] };
  }>;

// A pass-through wrapper: it renders its block with no surrounding element, so it
// declares no `Element` (it does not accept `...attributes`).
const empty: TemplateOnlyComponent<{ Blocks: { default: [] } }> = <template>
  {{! eslint-disable ember/template-no-yield-only }}{{yield}}
</template>;

const shortcuts: { [K in ShortcutTag]: ElementWrapper<K> } = {
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
// A known tag name (or a union of known tag names): the wrapper is typed with the
// exact element, so consumers get per-tag attribute checking. Passing a union
// (for example a runtime-chosen `"a" | "button"`) yields a wrapper that accepts
// any attribute valid on either element.
export default function dElement<T extends keyof HTMLElementTagNameMap>(
  tagName: T
): ComponentLike<{
  Element: HTMLElementTagNameMap[T];
  Blocks: { default: [] };
}>;

// An empty string (pass-through wrapper) or a dynamic tag name only known at
// runtime: the element type falls back to the generic HTMLElement.
export default function dElement(
  tagName: string
): ComponentLike<{ Element: HTMLElement; Blocks: { default: [] } }>;

export default function dElement(
  tagName: string
): ComponentLike<{ Element: HTMLElement; Blocks: { default: [] } }> {
  if (typeof tagName !== "string") {
    throw new Error(
      `element helper only accepts string literals, you passed ${tagName}`
    );
  }

  // The concrete wrapper is one of several component shapes (element-typed
  // shortcut, block-only pass-through, or classic-component fallback); the public
  // overloads above are the real contract, so the body erases the exact shape.
  let wrapper: unknown;

  if (tagName === "") {
    wrapper = empty;
  } else if (shortcuts[tagName as ShortcutTag]) {
    wrapper = shortcuts[tagName as ShortcutTag];
  } else {
    wrapper = <template>
      {{! @glint-nocheck: @ember/component (ClassicComponent) is not glint-typed }}
      <ClassicComponent
        @tagName={{tagName}}
        ...attributes
      >{{yield}}</ClassicComponent>
    </template>;
  }

  return wrapper as ComponentLike<{
    Element: HTMLElement;
    Blocks: { default: [] };
  }>;
}
