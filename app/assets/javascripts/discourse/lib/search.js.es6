import { ajax } from 'discourse/lib/ajax';
import { findRawTemplate } from 'discourse/lib/raw-templates';
import { TAG_HASHTAG_POSTFIX } from 'discourse/lib/tag-hashtags';
import { SEPARATOR } from 'discourse/lib/category-hashtags';
import Category from 'discourse/models/category';
import { search as searchCategoryTag  } from 'discourse/lib/category-tag-search';
import userSearch from 'discourse/lib/user-search';

export function translateResults(results, opts) {

  const User = require('discourse/models/user').default;
  const Post = require('discourse/models/post').default;
  const Topic = require('discourse/models/topic').default;

  if (!opts) opts = {};

  // Topics might not be included
  if (!results.topics) { results.topics = []; }
  if (!results.users) { results.users = []; }
  if (!results.posts) { results.posts = []; }
  if (!results.categories) { results.categories = []; }

  const topicMap = {};
  results.topics = results.topics.map(function(topic){
    topic = Topic.create(topic);
    topicMap[topic.id] = topic;
    return topic;
  });

  results.posts = results.posts.map(post => {
    if (post.username) {
      post.userPath = Discourse.getURL(`/users/${post.username.toLowerCase()}`);
    }
    post = Post.create(post);
    post.set('topic', topicMap[post.topic_id]);
    return post;
  });

  results.users = results.users.map(function(user){
    user = User.create(user);
    return user;
  });

  results.categories = results.categories.map(function(category){
    return Category.list().findBy('id', category.id);
  }).compact();

  const r = results.grouped_search_result;
  results.resultTypes = [];

  // TODO: consider refactoring front end to take a better structure
  if (r) {
    [['topic','posts'],['user','users'],['category','categories']].forEach(function(pair){
      const type = pair[0], name = pair[1];
      if (results[name].length > 0) {
        var result = {
          results: results[name],
          componentName: "search-result-" + ((opts.searchContext && opts.searchContext.type === 'topic' && type === 'topic') ? 'post' : type),
          type,
          more: r['more_' + name]
        };

        if (result.more && name === "posts" && opts.fullSearchUrl) {
          result.more = false;
          result.moreUrl = opts.fullSearchUrl;
        }

        results.resultTypes.push(result);
      }
    });
  }

  const noResults = !!(results.topics.length === 0 &&
                     results.posts.length === 0 &&
                     results.users.length === 0 &&
                     results.categories.length === 0);

  return noResults ? null : Em.Object.create(results);
}

export function searchForTerm(term, opts) {
  if (!opts) opts = {};

  // Only include the data we have
  const data = { term: term, include_blurbs: 'true' };
  if (opts.typeFilter) data.type_filter = opts.typeFilter;
  if (opts.searchForId) data.search_for_id = true;

  if (opts.searchContext) {
    data.search_context = {
      type: opts.searchContext.type,
      id: opts.searchContext.id
    };
  }

  var promise = ajax('/search/query', { data: data });

  promise.then(function(results){
    return translateResults(results, opts);
  });

  return promise;
}

export function searchContextDescription(type, name) {
  if (type) {
    switch(type) {
      case 'topic':
        return I18n.t('search.context.topic');
      case 'user':
        return I18n.t('search.context.user', {username: name});
      case 'category':
        return I18n.t('search.context.category', {category: name});
      case 'private_messages':
        return I18n.t('search.context.private_messages');
    }
  }
};

export function getSearchKey(args) {
  return args.q + "|" + ((args.searchContext && args.searchContext.type) || "") + "|" +
                      ((args.searchContext && args.searchContext.id) || "");
};

export function isValidSearchTerm(searchTerm) {
  if (searchTerm) {
    return searchTerm.trim().length >= Discourse.SiteSettings.min_search_term_length;
  } else {
    return false;
  }
};

export function applySearchAutocomplete($input, siteSettings, appEvents) {
  const afterComplete = function() {
    if (appEvents) {
      appEvents.trigger("search-autocomplete:after-complete");
    }
  };

  $input.autocomplete({
    template: findRawTemplate('category-tag-autocomplete'),
    key: '#',
    width: '100%',
    treatAsTextarea: true,
    transformComplete(obj) {
      if (obj.model) {
        return Category.slugFor(obj.model, SEPARATOR);
      } else {
        return `${obj.text}${TAG_HASHTAG_POSTFIX}`;
      }
    },
    dataSource(term) {
      return searchCategoryTag(term, siteSettings);
    },
    afterComplete
  });

  $input.autocomplete({
    template: findRawTemplate('user-selector-autocomplete'),
    key: "@",
    width: '100%',
    treatAsTextarea: true,
    transformComplete: v => v.username || v.name,
    dataSource: term => userSearch({ term, includeGroups: true }),
    afterComplete
  });
};
