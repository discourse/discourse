import EmberObject from "@ember/object";
import { Promise } from "rsvp";
import RestModel from "discourse/models/rest";
import Session from "discourse/models/session";
import User from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";
import { getOwner } from "discourse-common/lib/get-owner";
import { isEmpty } from "@ember/utils";
import { notEmpty } from "@ember/object/computed";
import deprecated from "discourse-common/lib/deprecated";

function extractByKey(collection, klass) {
  const retval = {};
  if (isEmpty(collection)) {
    return retval;
  }

  collection.forEach(function (item) {
    retval[item.id] = klass.create(item);
  });
  return retval;
}

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
    const topicIds = new Set();
    this.topics.forEach((topic) => topicIds.add(topic.id));

    topics.forEach((topic) => {
      if (!topicIds.has(topic.id)) {
        callback(topic);
      }
    });
  },

  updateSortParams(order, ascending) {
    let params = Object.assign({}, this.params || {});

    if (params.q) {
      // search is unique, nothing else allowed with it
      params = { q: params.q };
    } else {
      params.order = order || params.order;
      params.ascending = ascending;
    }

    this.set("params", params);
  },

  updateNewListScopeParam(newScope) {
    let params = Object.assign({}, this.params || {});

    if (params.q) {
      params = { q: params.q };
    } else {
      params.s = newScope;
    }

    this.set("params", params);
  },

  loadMore() {
    if (this.loadingMore) {
      return Promise.resolve();
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

      return ajax({ url: moreUrl }).then((result) => {
        let topicsAdded = 0;

        if (result) {
          // the new topics loaded from the server
          const newTopics = TopicList.topicsFrom(this.store, result);

          this.forEachNew(newTopics, (t) => {
            t.set("highlight", topicsAdded++ === 0);
            this.topics.pushObject(t);
          });

          this.setProperties({
            loadingMore: false,
            more_topics_url: result.topic_list.more_topics_url,
          });

          Session.currentProp("topicList", this);
          return { moreTopicsUrl: this.more_topics_url, newTopics };
        }
      });
    } else {
      // Return a promise indicating no more results
      return Promise.resolve();
    }
  },

  // loads topics with these ids "before" the current topics
  loadBefore(topic_ids, storeInSession) {
    // refresh dupes
    this.topics.removeObjects(
      this.topics.filter((topic) => topic_ids.includes(topic.id))
    );

    const url = `/${this.filter}.json?topic_ids=${topic_ids.join(",")}`;

    return ajax({ url, data: this.params }).then((result) => {
      let i = 0;
      this.forEachNew(TopicList.topicsFrom(this.store, result), (t) => {
        // highlight the first of the new topics so we can get a visual feedback
        t.set("highlight", true);
        this.topics.insertAt(i, t);
        i++;
      });

      if (storeInSession) {
        Session.currentProp("topicList", this);
      }
    });
  },
});

TopicList.reopenClass({
  topicsFrom(store, result, opts) {
    if (!result) {
      return;
    }

    opts = opts || {};
    let listKey = opts.listKey || "topics";

    // Stitch together our side loaded data

    const users = extractByKey(result.users, User);
    const groups = extractByKey(result.primary_groups, EmberObject);

    return result.topic_list[listKey].map((t) => {
      t.posters.forEach((p) => {
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
        t.participants.forEach((p) => (p.user = users[p.user_id]));
      }

      return store.createRecord("topic", t);
    });
  },

  munge(json, store) {
    json.inserted = json.inserted || [];
    json.can_create_topic = json.topic_list.can_create_topic;
    json.more_topics_url = json.topic_list.more_topics_url;
    json.for_period = json.topic_list.for_period;
    json.loaded = true;
    json.per_page = json.topic_list.per_page;
    json.topics = this.topicsFrom(store, json);

    if (json.topic_list.shared_drafts) {
      json.sharedDrafts = this.topicsFrom(store, json, {
        listKey: "shared_drafts",
      });
    }

    return json;
  },

  find(filter, params) {
    deprecated(
      `TopicList.find is deprecated. Use \`findFiltered("topicList")\` on the \`store\` service instead.`,
      {
        id: "topic-list-find",
        since: "3.1.0.beta5",
        dropFrom: "3.2.0.beta1",
      }
    );

    const store = getOwner(this).lookup("service:store");
    return store.findFiltered("topicList", { filter, params });
  },

  // hide the category when it has no children
  hideUniformCategory(list, category) {
    list.set("hideCategory", !displayCategoryInList(list.site, category));
  },
});

export default TopicList;
