import { queryParams } from 'discourse/controllers/discovery-sortable';
import { defaultHomepage } from 'discourse/lib/utilities';

// A helper to build a topic route for a filter
function filterQueryParams(params, defaultParams) {
  const findOpts = defaultParams || {};
  if (params) {
    Object.keys(queryParams).forEach(function(opt) {
      if (params[opt]) { findOpts[opt] = params[opt]; }
    });
  }
  return findOpts;
}

function findTopicList(store, tracking, filter, filterParams, extras) {
  extras = extras || {};
  return new Ember.RSVP.Promise(function(resolve) {
    const session = Discourse.Session.current();

    if (extras.cached) {
      const cachedList = session.get('topicList');

      // Try to use the cached version if it exists and is greater than the topics per page
      if (cachedList && (cachedList.get('filter') === filter) &&
        (cachedList.get('topics.length') || 0) > cachedList.get('per_page') &&
        _.isEqual(cachedList.get('listParams'), filterParams)) {
          cachedList.set('loaded', true);

          if (tracking) {
            tracking.updateTopics(cachedList.get('topics'));
          }
          return resolve(cachedList);
        }
      session.set('topicList', null);
    } else {
      // Clear the cache
      session.setProperties({topicList: null, topicListScrollPosition: null});
    }

    // Clean up any string parameters that might slip through
    filterParams = filterParams || {};
    Object.keys(filterParams).forEach(function(k) {
      const val = filterParams[k];
      if (val === "undefined" || val === "null" || val === 'false') {
        filterParams[k] = undefined;
      }
    });

    return resolve(store.findFiltered('topicList', { filter, params: filterParams || {} }));
  }).then(function(list) {
    list.set('listParams', filterParams);
    if (tracking) {
      tracking.sync(list, list.filter);
      tracking.trackIncoming(list.filter);
    }
    Discourse.Session.currentProp('topicList', list);
    return list;
  });
}

export default function(filter, extras) {
  extras = extras || {};
  return Discourse.Route.extend({
    queryParams,

    beforeModel() {
      this.controllerFor('navigation/default').set('filterMode', filter);
    },

    model(data, transition) {
      // attempt to stop early cause we need this to be called before .sync
      this.screenTrack.stop();

      const findOpts = filterQueryParams(data),
            findExtras = { cached: this.isPoppedState(transition) };

      return findTopicList(this.store, this.topicTrackingState, filter, findOpts, findExtras);
    },

    titleToken() {
      if (filter === defaultHomepage()) { return; }

      const filterText = I18n.t('filters.' + filter.replace('/', '.') + '.title');
      return I18n.t('filters.with_topics', {filter: filterText});
    },

    setupController(controller, model) {
      const topicOpts = {
        model,
        category: null,
        period: model.get('for_period') || (filter.indexOf('/') > 0 ? filter.split('/')[1] : ''),
        selected: [],
        expandGloballyPinned: true
      };

      const params = model.get('params');
      if (params && Object.keys(params).length) {
        if (params.order !== undefined) {
          topicOpts.order = params.order;
        }
        if (params.ascending !== undefined) {
          topicOpts.ascending = params.ascending;
        }
      }
      this.controllerFor('discovery/topics').setProperties(topicOpts);

      this.openTopicDraft(model);
      this.controllerFor('navigation/default').set('canCreateTopic', model.get('can_create_topic'));
    },

    resetController(controller, isExiting) {
      if (isExiting) {
        controller.setProperties({ order: "default", ascending: false });
      }
    },

    renderTemplate() {
      this.render('navigation/default', { outlet: 'navigation-bar' });
      this.render('discovery/topics', { controller: 'discovery/topics', outlet: 'list-container' });
    }
  }, extras);
}

export { filterQueryParams, findTopicList };
