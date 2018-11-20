import { rawConnectorsFor } from "discourse/lib/plugin-connectors";

Handlebars.registerHelper("raw-plugin-outlet", function(args) {
  const connectors = rawConnectorsFor(args.hash.name);
  if (connectors.length) {
    const output = connectors.map(c => c.template({ context: this }));
    return new Handlebars.SafeString(output.join(""));
  }
});
