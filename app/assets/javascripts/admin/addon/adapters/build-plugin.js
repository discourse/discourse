import RestAdapter from "discourse/adapters/rest";

/** @returns {any} */
export default function buildPluginAdapter(pluginName) {
  return class extends RestAdapter {
    pathFor(store, type, findArgs) {
      return (
        "/admin/plugins/" + pluginName + super.pathFor(store, type, findArgs)
      );
    }
  };
}
