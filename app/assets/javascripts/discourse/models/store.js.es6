import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import ResultSet from "discourse/models/result-set";
import { getRegister } from "discourse-common/lib/get-owner";

let _identityMap;

// You should only call this if you're a test scaffold
function flushMap() {
  _identityMap = {};
}

function storeMap(type, id, obj) {
  if (!id) {
    return;
  }

  _identityMap[type] = _identityMap[type] || {};
  _identityMap[type][id] = obj;
}

function fromMap(type, id) {
  const byType = _identityMap[type];
  if (byType) {
    return byType[id];
  }
}

function removeMap(type, id) {
  const byType = _identityMap[type];
  if (byType) {
    delete byType[id];
  }
}

function findAndRemoveMap(type, id) {
  const byType = _identityMap[type];
  if (byType) {
    const result = byType[id];
    delete byType[id];
    return result;
  }
}

flushMap();

export default Ember.Object.extend({
  _plurals: {
    "post-reply": "post-replies",
    "post-reply-history": "post_reply_histories",
    "moderation-history": "moderation_history"
  },

  init() {
    this._super(...arguments);
    this.register = this.register || getRegister(this);
  },

  pluralize(thing) {
    return this._plurals[thing] || thing + "s";
  },

  addPluralization(thing, plural) {
    this._plurals[thing] = plural;
  },

  findAll(type, findArgs) {
    const adapter = this.adapterFor(type);

    let store = this;
    return adapter.findAll(this, type, findArgs).then(result => {
      let results = this._resultSet(type, result);
      if (adapter.afterFindAll) {
        results = adapter.afterFindAll(results, {
          lookup(subType, id) {
            return store._lookupSubType(subType, type, id, result);
          }
        });
      }
      return results;
    });
  },

  // Mostly for legacy, things like TopicList without ResultSets
  findFiltered(type, findArgs) {
    const self = this;
    return this.adapterFor(type)
      .find(this, type, findArgs)
      .then(function(result) {
        return self._build(type, result);
      });
  },

  _hydrateFindResults(result, type, findArgs) {
    if (typeof findArgs === "object") {
      return this._resultSet(type, result, findArgs);
    } else {
      return this._hydrate(type, result[Ember.String.underscore(type)], result);
    }
  },

  // See if the store can find stale data. We sometimes prefer to show stale data and
  // refresh it in the background.
  findStale(type, findArgs, opts) {
    const stale = this.adapterFor(type).findStale(this, type, findArgs, opts);
    return {
      hasResults: stale !== undefined,
      results: stale,
      refresh: () => this.find(type, findArgs, opts)
    };
  },

  find(type, findArgs, opts) {
    var adapter = this.adapterFor(type);
    return adapter.find(this, type, findArgs, opts).then(result => {
      var hydrated = this._hydrateFindResults(result, type, findArgs, opts);

      if (result.extras) {
        hydrated.set("extras", result.extras);
      }

      if (adapter.cache) {
        const stale = adapter.findStale(this, type, findArgs, opts);
        hydrated = this._updateStale(stale, hydrated);
        adapter.cacheFind(this, type, findArgs, opts, hydrated);
      }
      return hydrated;
    });
  },

  _updateStale(stale, hydrated) {
    if (!stale) {
      return hydrated;
    }

    hydrated.set(
      "content",
      hydrated.get("content").map(item => {
        var staleItem = stale.content.findBy("id", item.get("id"));
        if (staleItem) {
          staleItem.setProperties(item);
        } else {
          staleItem = item;
        }
        return staleItem;
      })
    );
    return hydrated;
  },

  refreshResults(resultSet, type, url) {
    const self = this;
    return ajax(url).then(result => {
      const typeName = Ember.String.underscore(self.pluralize(type));
      const content = result[typeName].map(obj =>
        self._hydrate(type, obj, result)
      );
      resultSet.set("content", content);
    });
  },

  appendResults(resultSet, type, url) {
    const self = this;

    return ajax(url).then(function(result) {
      let typeName = Ember.String.underscore(self.pluralize(type));

      let pageTarget = result.meta || result;
      let totalRows =
        pageTarget["total_rows_" + typeName] || resultSet.get("totalRows");
      let loadMoreUrl = pageTarget["load_more_" + typeName];
      let content = result[typeName].map(obj =>
        self._hydrate(type, obj, result)
      );

      resultSet.setProperties({ totalRows, loadMoreUrl });
      resultSet.get("content").pushObjects(content);

      // If we've loaded them all, clear the load more URL
      if (resultSet.get("length") >= totalRows) {
        resultSet.set("loadMoreUrl", null);
      }
    });
  },

  update(type, id, attrs) {
    return this.adapterFor(type).update(this, type, id, attrs, function(
      result
    ) {
      if (result && result[type] && result[type].id) {
        const oldRecord = findAndRemoveMap(type, id);
        storeMap(type, result[type].id, oldRecord);
      }
      return result;
    });
  },

  createRecord(type, attrs) {
    attrs = attrs || {};
    return !!attrs.id ? this._hydrate(type, attrs) : this._build(type, attrs);
  },

  destroyRecord(type, record) {
    // If the record is new, don't perform an Ajax call
    if (record.get("isNew")) {
      removeMap(type, record.get("id"));
      return Ember.RSVP.Promise.resolve(true);
    }

    return this.adapterFor(type)
      .destroyRecord(this, type, record)
      .then(function(result) {
        removeMap(type, record.get("id"));
        return result;
      });
  },

  _resultSet(type, result, findArgs) {
    const typeName = Ember.String.underscore(this.pluralize(type));
    const content = result[typeName].map(obj =>
      this._hydrate(type, obj, result)
    );

    let pageTarget = result.meta || result;

    const createArgs = {
      content,
      findArgs,
      totalRows: pageTarget["total_rows_" + typeName] || content.length,
      loadMoreUrl: pageTarget["load_more_" + typeName],
      refreshUrl: pageTarget["refresh_" + typeName],
      store: this,
      __type: type
    };

    if (result.extras) {
      createArgs.extras = result.extras;
    }

    return ResultSet.create(createArgs);
  },

  _build(type, obj) {
    obj.store = this;
    obj.__type = type;
    obj.__state = obj.id ? "created" : "new";

    // TODO: Have injections be automatic
    obj.topicTrackingState = this.register.lookup("topic-tracking-state:main");
    obj.keyValueStore = this.register.lookup("key-value-store:main");
    obj.siteSettings = this.register.lookup("site-settings:main");

    const klass = this.register.lookupFactory("model:" + type) || RestModel;
    const model = klass.create(obj);

    storeMap(type, obj.id, model);
    return model;
  },

  adapterFor(type) {
    return (
      this.register.lookup("adapter:" + type) ||
      this.register.lookup("adapter:rest")
    );
  },

  _lookupSubType(subType, type, id, root) {
    // cheat: we know we already have categories in memory
    // TODO: topics do their own resolving of `category_id`
    // to category. That should either respect this or be
    // removed.
    if (subType === "category" && type !== "topic") {
      return Discourse.Category.findById(id);
    }

    if (root.meta && root.meta.types) {
      subType = root.meta.types[subType] || subType;
    }

    const pluralType = this.pluralize(subType);
    const collection = root[this.pluralize(subType)];
    if (collection) {
      const hashedProp = "__hashed_" + pluralType;
      let hashedCollection = root[hashedProp];
      if (!hashedCollection) {
        hashedCollection = {};
        collection.forEach(function(it) {
          hashedCollection[it.id] = it;
        });
        root[hashedProp] = hashedCollection;
      }

      const found = hashedCollection[id];
      if (found) {
        const hydrated = this._hydrate(subType, found, root);
        hashedCollection[id] = hydrated;
        return hydrated;
      }
    }
  },

  _hydrateEmbedded(type, obj, root) {
    const self = this;
    Object.keys(obj).forEach(function(k) {
      const m = /(.+)\_id(s?)$/.exec(k);
      if (m) {
        const subType = m[1];

        if (m[2]) {
          const hydrated = obj[k].map(function(id) {
            return self._lookupSubType(subType, type, id, root);
          });
          obj[self.pluralize(subType)] = hydrated || [];
          delete obj[k];
        } else {
          const hydrated = self._lookupSubType(subType, type, obj[k], root);
          if (hydrated) {
            obj[subType] = hydrated;
            delete obj[k];
          }
        }
      }
    });
  },

  _hydrate(type, obj, root) {
    if (!obj) {
      throw new Error("Can't hydrate " + type + " of `null`");
    }

    const id = obj.id;
    if (!id) {
      throw new Error("Can't hydrate " + type + " without an `id`");
    }

    root = root || obj;

    // Experimental: If serialized with a certain option we'll wire up embedded objects
    // automatically.
    if (root.__rest_serializer === "1") {
      this._hydrateEmbedded(type, obj, root);
    }

    const existing = fromMap(type, id);
    if (existing === obj) {
      return existing;
    }

    if (existing) {
      delete obj.id;
      let klass = this.register.lookupFactory("model:" + type);

      if (klass && klass.class) {
        klass = klass.class;
      }

      if (!klass) {
        klass = RestModel;
      }

      existing.setProperties(klass.munge(obj));
      obj.id = id;
      return existing;
    }

    return this._build(type, obj);
  }
});

export { flushMap };
