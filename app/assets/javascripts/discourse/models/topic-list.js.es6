import { notEmpty } from "@ember/object/computed";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import Model from "discourse/models/model";
import { getOwner } from "discourse-common/lib/get-owner";

// Whether to show the category badge in topic lists
function displayCategoryInList(site, category) {
  if (category) {
    if (category.has_children) {
      return true;
    }

    const draftCategoryId = site.shared_drafts_category_id;
    if (draftCategoryId && category.id === draftCategoryId) {
      return true;
    }

    return false;
  }

  return true;
}

const TopicList = RestModel.extend({
  canLoadMore: notEmpty("more_topics_url"),

  forEachNew(topics, callback) {
    const topicIds = [];

    this.topics.forEach(topic => (topicIds[topic.id] = true));

    topics.forEach(topic => {
      if (!topicIds[topic.id]) {
        callback(topic);
      }
    });
  },

  refreshSort(order, ascending) {
    let params = this.params || {};

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
    if (this.loadingMore) {
      return Ember.RSVP.resolve();
    }

    let moreUrl = this.more_topics_url;
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

      this.set("loadingMore", true);

      return ajax({ url: moreUrl }).then(result => {
        let topicsAdded = 0;

        if (result) {
          // the new topics loaded from the server
          const newTopics = TopicList.topicsFrom(this.store, result);

          this.forEachNew(newTopics, t => {
            t.set("highlight", topicsAdded++ === 0);
            this.topics.pushObject(t);
          });

          this.setProperties({
            loadingMore: false,
            more_topics_url: result.topic_list.more_topics_url
          });

          Discourse.Session.currentProp("topicList", this);
          return this.more_topics_url;
        }
      });
    } else {
      // Return a promise indicating no more results
      return Ember.RSVP.resolve();
    }
  },

  // loads topics with these ids "before" the current topics
  loadBefore(topic_ids, storeInSession) {
    // refresh dupes
    this.topics.removeObjects(
      this.topics.filter(topic => topic_ids.indexOf(topic.id) >= 0)
    );

    const url = `${Discourse.getURL("/")}${
      this.filter
    }.json?topic_ids=${topic_ids.join(",")}`;

    return ajax({ url, data: this.params }).then(result => {
      let i = 0;
      this.forEachNew(TopicList.topicsFrom(this.store, result), t => {
        // highlight the first of the new topics so we can get a visual feedback
        t.set("highlight", true);
        this.topics.insertAt(i, t);
        i++;
      });

      if (storeInSession) Discourse.Session.currentProp("topicList", this);
    });
  }
});

TopicList.reopenClass({
  topicsFrom(store, result, opts) {
    if (!result) return;

    opts = opts || {};
    let listKey = opts.listKey || "topics";

    // Stitch together our side loaded data

    const categories = Discourse.Category.list(),
      users = Model.extractByKey(result.users, Discourse.User),
      groups = Model.extractByKey(result.primary_groups, EmberObject);

    return result.topic_list[listKey].map(t => {
      t.category = categories.findBy("id", t.category_id);
      t.posters.forEach(p => {
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
        t.participants.forEach(p => (p.user = users[p.user_id]));
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
    const store = getOwner(this).lookup("service:store");
    return store.findFiltered("topicList", { filter, params });
  },

  // hide the category when it has no children
  hideUniformCategory(list, category) {
    list.set("hideCategory", !displayCategoryInList(list.site, category));
  }
});

export default TopicList;
