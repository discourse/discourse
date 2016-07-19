import { ajax } from 'discourse/lib/ajax';
import RestAdapter from 'discourse/adapters/rest';

export default RestAdapter.extend({
  find(store, type, findArgs) {
    if (findArgs.similar) {
      return ajax("/topics/similar_to", { data: findArgs.similar });
    } else {
      return this._super(store, type, findArgs);
    }
  }
});
