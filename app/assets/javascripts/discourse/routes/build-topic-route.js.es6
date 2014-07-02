// A helper to build a topic route for a filter
export default function(filter) {
  return Discourse.Route.extend({
    queryParams: {
      sort: { replace: true },
      ascending: { replace: true },
      status: { replace: true }
    },

    beforeModel: function() {
      this.controllerFor('navigation/default').set('filterMode', filter);
    },

    model: function(data, transaction) {

      var params = transaction.queryParams;

      // attempt to stop early cause we need this to be called before .sync
      Discourse.ScreenTrack.current().stop();

      var findOpts = {};
      if (params && params.order) { findOpts.order = params.order; }
      if (params && params.ascending) { findOpts.ascending = params.ascending; }
      if (params && params.status) { findOpts.status = params.status; }


      return Discourse.TopicList.list(filter, findOpts).then(function(list) {
        var tracking = Discourse.TopicTrackingState.current();
        if (tracking) {
          tracking.sync(list, filter);
          tracking.trackIncoming(filter);
        }
        return list;
      });
    },

    setupController: function(controller, model, trans) {

      controller.setProperties({
        order: Em.get(trans, 'queryParams.order'),
        ascending: Em.get(trans, 'queryParams.ascending')
      });

      var period = filter.indexOf('/') > 0 ? filter.split('/')[1] : '',
          filterText = I18n.t('filters.' + filter.replace('/', '.') + '.title', {count: 0});

      if (filter === Discourse.Utilities.defaultHomepage()) {
        Discourse.set('title', '');
      } else {
        Discourse.set('title', I18n.t('filters.with_topics', {filter: filterText}));
      }

      this.controllerFor('discovery/topics').setProperties({
        model: model,
        category: null,
        period: period,
        selected: []
      });

      // If there's a draft, open the create topic composer
      if (model.draft) {
        var composer = this.controllerFor('composer');
        if (!composer.get('model.viewOpen')) {
          composer.open({
            action: Discourse.Composer.CREATE_TOPIC,
            draft: model.draft,
            draftKey: model.draft_key,
            draftSequence: model.draft_sequence
          });
        }
      }

      this.controllerFor('navigation/default').set('canCreateTopic', model.get('can_create_topic'));
    },

    renderTemplate: function() {
      this.render('navigation/default', { outlet: 'navigation-bar' });
      this.render('discovery/topics', { controller: 'discovery/topics', outlet: 'list-container' });
    }
  });
}

