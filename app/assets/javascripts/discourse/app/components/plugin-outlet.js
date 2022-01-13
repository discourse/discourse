import {
  buildArgsWithDeprecations,
  renderedConnectorsFor,
} from "discourse/lib/plugin-connectors";
/**
   A plugin outlet is an extension point for templates where other templates can
   be inserted by plugins.

   ## Usage

   If your handlebars template has:

   ```handlebars
     {{plugin-outlet name="evil-trout"}}
   ```

   Then any handlebars files you create in the `connectors/evil-trout` directory
   will automatically be appended. For example:

   plugins/hello/assets/javascripts/discourse/templates/connectors/evil-trout/hello.hbs

   With the contents:

   ```handlebars
     <b>Hello World</b>
   ```

   Will insert <b>Hello World</b> at that point in the template.

   ## Disabling

   If a plugin returns a disabled status, the outlets will not be wired up for it.
   The list of disabled plugins is returned via the `Site` singleton.

**/
import Component from "@ember/component";

export default Component.extend({
  tagName: "",
  connectorTagName: "",
  connectors: null,

  init() {
    this._super(...arguments);
    const name = this.name;
    if (name) {
      const args = buildArgsWithDeprecations(
        this.args || {},
        this.deprecatedArgs || {}
      );
      this.set("connectors", renderedConnectorsFor(name, args, this));
    }
  },
});
