import ClassicComponent from "@ember/component";

const empty = <template>{{yield}}</template>;
const shortcuts = {
  div: <template><div ...attributes>{{yield}}</div></template>,
  span: <template><span ...attributes>{{yield}}</span></template>,
  form: <template><form ...attributes>{{yield}}</form></template>,
  a: <template><a ...attributes>{{yield}}</a></template>,
  button: <template><button ...attributes>{{yield}}</button></template>,
};

/**
 * Returns a wrapper component with the given tagname, or an empty wrapper for an empty string.
 * Similar to the reference implementation of RFC389, with higher-performance shortcuts for common elements.
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
