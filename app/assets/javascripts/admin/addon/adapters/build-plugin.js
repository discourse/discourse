import RestAdapter from "discourse/adapters/rest";

export default function buildPluginAdapter(pluginName) {
  return class extends RestAdapter {
    pathFor(store, type, findArgs) {
      return (
        "/admin/plugins/" + pluginName + this._super(store, type, findArgs)
      );
    }
  };
}
