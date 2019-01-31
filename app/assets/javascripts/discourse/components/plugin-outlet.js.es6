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
import { renderedConnectorsFor } from "discourse/lib/plugin-connectors";

export default Ember.Component.extend({
  tagName: "span",
  connectors: null,

  init() {
    // This should be the future default
    if (this.get("noTags")) {
      this.set("tagName", "");
      this.set("connectorTagName", "");
    }

    this._super(...arguments);
    const name = this.get("name");
    if (name) {
      const args = this.get("args");
      this.set("connectors", renderedConnectorsFor(name, args, this));
    }
  }
});
