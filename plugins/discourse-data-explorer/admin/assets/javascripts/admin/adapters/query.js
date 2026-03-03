import { optionalRequire } from "discourse/lib/utilities";

const buildPluginAdapter = optionalRequire(
  "discourse/admin/adapters/build-plugin"
);

export default buildPluginAdapter
  ? buildPluginAdapter("discourse-data-explorer").extend({})
  : null; // Not logged in as admin, the adapter isn't needed
