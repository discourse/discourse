import { optionalRequire } from "discourse/lib/utilities";

const buildPluginAdapter = optionalRequire("admin/adapters/build-plugin");

export default buildPluginAdapter
  ? buildPluginAdapter("explorer").extend({})
  : null; // Not logged in as admin, the adapter isn't needed
