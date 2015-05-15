import RestAdapter from 'discourse/adapters/rest';

export default function buildPluginAdapter(pluginName) {
  return RestAdapter.extend({
    pathFor(store, type) {
      return "/admin/plugins/" + pluginName + this._super(store, type);
    }
  });
}
