import { ajax } from 'discourse/lib/ajax';
import RestAdapter from 'discourse/adapters/rest';
import Topic from 'discourse/models/topic';

export function Result(payload, responseJson) {
  this.payload = payload;
  this.responseJson = responseJson;
  this.target = null;
}

export default RestAdapter.extend({
  update(store, type, id, attrs) {
    const data = {};
    const typeField = Ember.String.underscore(type);
    Object.assign(data, attrs);
    return this.pathFor(store, type, id).then(function(path) {
      return ajax(path, { method: 'PUT', data }).then(function(json) {
        const result = new Result(json[typeField], json);
        console.log(result);
        return result;
      });
    });
  },
  pathFor(store, type, findArgs) {
    var self = this;
    return Topic.find(findArgs, {}).then(function(result) {
      if (result) {
        self.set('path', self.basePath(store, type, findArgs) + 't/' + result.slug);
      }
      return self.appendQueryParams(self.get('path'), findArgs);
    });
  },
  find(store, type, findArgs) {
    if (findArgs.similar) {
      return ajax("/topics/similar_to", { data: findArgs.similar });
    } else {
      return this._super(store, type, findArgs);
    }
  }
});
