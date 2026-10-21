/* eslint-disable ember/no-classic-components */
import ClassicComponent from "@ember/component";
import type { TemplateOnlyComponent } from "@ember/component/template-only";
import type { ComponentLike } from "@glint/template";

/** The tag names that have a dedicated, higher-performance shortcut wrapper. */
type ShortcutTag =
  | "div"
  | "span"
  | "form"
  | "a"
  | "button"
  | "td"
  | "aside"
  | "ul"
  | "li";

/**
 * A wrapper component for a single known tag, typed with the matching element so
 * that `...attributes` and named attributes are checked against that element.
 */
type ElementWrapper<T extends keyof HTMLElementTagNameMap> =
  TemplateOnlyComponent<{
    Element: HTMLElementTagNameMap[T];
    Blocks: { default: [] };
  }>;

/**
 * A pass-through wrapper: it renders its block with no surrounding element, so it
 * declares no `Element` (it does not accept `...attributes`).
 */
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
  ul: <template>
    <ul ...attributes>{{yield}}</ul>
  </template>,
  li: <template>
    <li ...attributes>{{yield}}</li>
  </template>,
};

/**
 * Wrappers built for tags outside the shortcut table, kept so a given tag always
 * resolves to the same component. A caller that picks its tag at runtime would
 * otherwise get a new component identity on every call, and rendering it would
 * tear down and rebuild the whole subtree instead of updating it.
 */
const fallbacks = new Map<string, unknown>();

/**
 * Returns a wrapper component that renders the given tag name, or an empty
 * pass-through wrapper for an empty string. Modeled on the reference
 * implementation of RFC389, with higher-performance shortcuts for common
 * elements.
 *
 * When the tag name is a known HTML tag, the wrapper is typed with the matching
 * element, so consumers get per-tag attribute checking (for example `href` on
 * an anchor, `disabled` on a button); any other string falls back to a generic
 * `HTMLElement` wrapper.
 *
 * Can be used directly in a template:
 *
 * ```hbs
 * {{#let (dElement @tagName) as |Wrapper|}}
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
 *   get wrapper() {
 *     return dElement(this.args.tagName);
 *   }
 *
 *   <template>
 *     <this.wrapper>
 *       Content
 *     </this.wrapper>
 *   </template>
 * }
 * ```
 *
 * @param tagName - The HTML tag name to render, or an empty string for a
 *   pass-through wrapper that renders its block with no surrounding element.
 * @returns A wrapper component that renders its block inside the given element.
 */
// The conditional distributes over unions, so a runtime-chosen tag such as
// `"a" | "button"` yields a wrapper accepting any attribute valid on either arm.
export default function dElement<T extends string>(
  tagName: T
): ComponentLike<{
  Element: T extends keyof HTMLElementTagNameMap
    ? HTMLElementTagNameMap[T]
    : HTMLElement;
  Blocks: { default: [] };
}>;

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
  // overload above is the real contract, so the body erases the exact shape.
  let wrapper: unknown;

  if (tagName === "") {
    wrapper = empty;
    // `hasOwn`, not a bare read: the table is a plain object, so a tag named after
    // an inherited member would otherwise resolve to that member.
  } else if (Object.hasOwn(shortcuts, tagName)) {
    wrapper = shortcuts[tagName as ShortcutTag];
  } else {
    const cached = fallbacks.get(tagName);
    if (cached) {
      wrapper = cached;
    } else {
      const fallback = <template>
        {{! @glint-nocheck: @ember/component (ClassicComponent) is not glint-typed }}
        <ClassicComponent
          ...attributes
          @tagName={{tagName}}
        >{{yield}}</ClassicComponent>
      </template>;
      fallbacks.set(tagName, fallback);
      wrapper = fallback;
    }
  }

  return wrapper as ComponentLike<{
    Element: HTMLElement;
    Blocks: { default: [] };
  }>;
}
