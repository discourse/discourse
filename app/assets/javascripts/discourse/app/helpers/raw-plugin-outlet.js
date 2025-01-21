import { htmlSafe } from "@ember/template";
import { rawConnectorsFor } from "discourse/lib/plugin-connectors";
import RawHandlebars from "discourse/lib/raw-handlebars";

RawHandlebars.registerHelper("raw-plugin-outlet", function (args) {
  const connectors = rawConnectorsFor(args.hash.name);
  if (connectors.length) {
    const output = connectors.map((c) => c.template({ context: this }));
    return htmlSafe(output.join(""));
  }
});
