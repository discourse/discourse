import { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";

let counter = 0;

/**
 * Generate HTML which can be inserted into a raw-hbs template to render a Glimmer component.
 * The result of this function must be rendered immediately, so that an `afterRender` hook
 * can access the element in the DOM and attach the glimmer component.
 *
 * Example usage:
 *
 *   ```hbs
 *   {{! raw-templates/something-cool.hbr }}
 *   {{{view.html}}}
 *   ```
 *
 *   ```gjs
 *   // raw-views/something-cool.gjs
 *   import EmberObject from "@ember/object";
 *   import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
 *
 *   export default class SomethingCool extends EmberObject {
 *     get html(){
 *       return rawRenderGlimmer(this, "div", <template>Hello {{@data.name}}</template>, { name: this.name });
 *     }
 *   ```
 *
 * And then this can be invoked from any other raw view (including raw plugin outlets) like:
 *
 *   ```hbs
 *   {{raw "something-cool" name="david"}}
 *   ```
 */
export default function rawRenderGlimmer(owner, renderInto, component, data) {
  const renderGlimmerService = getOwner(owner).lookup("service:render-glimmer");

  counter++;
  const id = `_render_glimmer_${counter}`;
  const [type, ...classNames] = renderInto.split(".");

  schedule("afterRender", () => {
    const element = document.getElementById(id);
    if (element) {
      const componentInfo = {
        element,
        component,
        data,
      };
      renderGlimmerService.add(componentInfo);
    }
  });

  return `<${type} id="${id}" class="${classNames.join(" ")}"></${type}>`;
}
