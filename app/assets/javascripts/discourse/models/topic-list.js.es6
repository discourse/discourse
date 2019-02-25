import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import Model from "discourse/models/model";

// Whether to show the category badge in topic lists
function displayCategoryInList(site, category) {
  if (category) {
    if (category.get("has_children")) {
      return true;
    }
    let draftCategoryId = site.get("shared_drafts_category_id");
    if (draftCategoryId && category.get("id") === draftCategoryId) {
      return true;
    }

    return false;
  }

  return true;
}

const TopicList = RestModel.extend({
  canLoadMore: Ember.computed.notEmpty("more_topics_url"),

  forEachNew(topics, callback) {
    const topicIds = [];

    this.get("topics").forEach(topic => (topicIds[topic.get("id")] = true));

    topics.forEach(topic => {
      if (!topicIds[topic.id]) {
        callback(topic);
      }
    });
  },

  refreshSort(order, ascending) {
    let params = this.get("params") || {};

    if (params.q) {
      // search is unique, nothing else allowed with it
      params = { q: params.q };
    } else {
      params.order = order || params.order;
      params.ascending = ascending;
    }

    this.set("params", params);
  },

  loadMore() {
    if (this.get("loadingMore")) {
      return Ember.RSVP.resolve();
    }

    let moreUrl = this.get("more_topics_url");
    if (moreUrl) {
      let [url, params] = moreUrl.split("?");

      // ensure we postfix with .json so username paths work
      // correctly
      if (!url.match(/\.json$/)) {
        url += ".json";
      }

      moreUrl = url;
      if (params) {
        moreUrl += "?" + params;
      }

      const self = this;
      this.set("loadingMore", true);

      const store = this.store;
      return ajax({ url: moreUrl }).then(function(result) {
        let topicsAdded = 0;

        if (result) {
          // the new topics loaded from the server
          const newTopics = TopicList.topicsFrom(store, result);
          const topics = self.get("topics");

          self.forEachNew(newTopics, function(t) {
            t.set("highlight", topicsAdded++ === 0);
            topics.pushObject(t);
          });

          self.setProperties({
            loadingMore: false,
            more_topics_url: result.topic_list.more_topics_url
          });

          Discourse.Session.currentProp("topicList", self);
          return self.get("more_topics_url");
        }
      });
    } else {
      // Return a promise indicating no more results
      return Ember.RSVP.resolve();
    }
  },

  // loads topics with these ids "before" the current topics
  loadBefore(topic_ids, storeInSession) {
    const topicList = this,
      topics = this.get("topics");

    // refresh dupes
    topics.removeObjects(
      topics.filter(topic => topic_ids.indexOf(topic.get("id")) >= 0)
    );

    const url = `${Discourse.getURL("/")}${this.get(
      "filter"
    )}.json?topic_ids=${topic_ids.join(",")}`;
    const store = this.store;

    return ajax({ url, data: this.get("params") }).then(result => {
      let i = 0;
      topicList.forEachNew(TopicList.topicsFrom(store, result), function(t) {
        // highlight the first of the new topics so we can get a visual feedback
        t.set("highlight", true);
        topics.insertAt(i, t);
        i++;
      });
      if (storeInSession) Discourse.Session.currentProp("topicList", topicList);
    });
  }
});

TopicList.reopenClass({
  topicsFrom(store, result, opts) {
    if (!result) {
      return;
    }

    opts = opts || {};
    let listKey = opts.listKey || "topics";

    // Stitch together our side loaded data

    const categories = Discourse.Category.list(),
      users = Model.extractByKey(result.users, Discourse.User),
      groups = Model.extractByKey(result.primary_groups, Ember.Object);

    return result.topic_list[listKey].map(function(t) {
      t.category = categories.findBy("id", t.category_id);
      t.posters.forEach(function(p) {
        p.user = users[p.user_id];
        p.extraClasses = p.extras;
        if (p.primary_group_id) {
          p.primary_group = groups[p.primary_group_id];
          if (p.primary_group) {
            p.extraClasses = `${p.extraClasses || ""} group-${
              p.primary_group.name
            }`;
          }
        }
      });
      if (t.participants) {
        t.participants.forEach(function(p) {
          p.user = users[p.user_id];
        });
      }
      return store.createRecord("topic", t);
    });
  },

  munge(json, store) {
    json.inserted = json.inserted || [];
    json.can_create_topic = json.topic_list.can_create_topic;
    json.more_topics_url = json.topic_list.more_topics_url;
    json.draft_key = json.topic_list.draft_key;
    json.draft_sequence = json.topic_list.draft_sequence;
    json.draft = json.topic_list.draft;
    json.for_period = json.topic_list.for_period;
    json.loaded = true;
    json.per_page = json.topic_list.per_page;
    json.topics = this.topicsFrom(store, json);

    if (json.topic_list.shared_drafts) {
      json.sharedDrafts = this.topicsFrom(store, json, {
        listKey: "shared_drafts"
      });
    }

    return json;
  },

  find(filter, params) {
    const store = Discourse.__container__.lookup("service:store");
    return store.findFiltered("topicList", { filter, params });
  },

  // hide the category when it has no children
  hideUniformCategory(list, category) {
    list.set("hideCategory", !displayCategoryInList(list.site, category));
  }
});

export default TopicList;
