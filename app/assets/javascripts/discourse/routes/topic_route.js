/**
  This route handles requests for topics

  @class TopicRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicRoute = Discourse.Route.extend({
  redirect: function() { Discourse.redirectIfLoginRequired(this); },

  queryParams: {
    filter: { replace: true },
    username_filters: { replace: true }
  },

  actions: {
    // Modals that can pop up within a topic
    showPosterExpansion: function(post) {
      this.controllerFor('poster-expansion').show(post);
    },

    composePrivateMessage: function(user) {
      var self = this;
      this.transitionTo('userActivity', user).then(function () {
        self.controllerFor('user-activity').send('composePrivateMessage');
      });
    },

    showFlags: function(post) {
      Discourse.Route.showModal(this, 'flag', post);
      this.controllerFor('flag').setProperties({ selected: null });
    },

    showFlagTopic: function(topic) {
      //Discourse.Route.showModal(this, 'flagTopic', topic);
      Discourse.Route.showModal(this, 'flag', topic);
      this.controllerFor('flag').setProperties({ selected: null, flagTopic: true });
    },

    showAutoClose: function() {
      Discourse.Route.showModal(this, 'editTopicAutoClose', this.modelFor('topic'));
      this.controllerFor('modal').set('modalClass', 'edit-auto-close-modal');
    },

    showInvite: function() {
      Discourse.Route.showModal(this, 'invite', this.modelFor('topic'));
      this.controllerFor('invite').reset();
    },

    showPrivateInvite: function() {
      Discourse.Route.showModal(this, 'invitePrivate', this.modelFor('topic'));
      this.controllerFor('invitePrivate').setProperties({
        email: null,
        error: false,
        saving: false,
        finished: false
      });
    },

    showHistory: function(post) {
      Discourse.Route.showModal(this, 'history', post);
      this.controllerFor('history').refresh(post.get("id"), post.get("version"));
      this.controllerFor('modal').set('modalClass', 'history-modal');
    },

    mergeTopic: function() {
      Discourse.Route.showModal(this, 'mergeTopic', this.modelFor('topic'));
    },

    splitTopic: function() {
      Discourse.Route.showModal(this, 'split-topic', this.modelFor('topic'));
    },

    changeOwner: function() {
      Discourse.Route.showModal(this, 'changeOwner', this.modelFor('topic'));
    },

    // Use replaceState to update the URL once it changes
    postChangedRoute: Discourse.debounce(function(currentPost) {
      // do nothing if we are transitioning to another route
      if (this.get("isTransitioning") || Discourse.TopicRoute.disableReplaceState) { return; }

      var topic = this.modelFor('topic');
      if (topic && currentPost) {
        var postUrl = topic.get('url');
        if (currentPost > 1) { postUrl += "/" + currentPost; }
        Discourse.URL.replaceState(postUrl);
      }
    }, 150),

    willTransition: function() { this.set("isTransitioning", true); return true; }

  },

  setupParams: function(topic, params) {
    var postStream = topic.get('postStream');
    postStream.set('summary', Em.get(params, 'filter') === 'summary');

    var usernames = Em.get(params, 'username_filters'),
        userFilters = postStream.get('userFilters');

    userFilters.clear();
    if (!Em.isEmpty(usernames) && usernames !== 'undefined') {
      userFilters.addObjects(usernames.split(','));
    }

    return topic;
  },

  model: function(params, transition) {
    var queryParams = transition.queryParams;

    var topic = this.modelFor('topic');
    if (topic && (topic.get('id') === parseInt(params.id, 10))) {
      this.setupParams(topic, queryParams);
      // If we have the existing model, refresh it
      return topic.get('postStream').refresh().then(function() {
        return topic;
      });
    } else {
      return this.setupParams(Discourse.Topic.create(_.omit(params, 'username_filters', 'filter')), queryParams);
    }
  },

  activate: function() {
    this._super();
    this.set("isTransitioning", false);

    var topic = this.modelFor('topic');
    Discourse.Session.currentProp('lastTopicIdViewed', parseInt(topic.get('id'), 10));
    this.controllerFor('search').set('searchContext', topic.get('searchContext'));
  },

  deactivate: function() {
    this._super();

    // Clear the search context
    this.controllerFor('search').set('searchContext', null);
    this.controllerFor('poster-expansion').set('visible', false);

    var topicController = this.controllerFor('topic'),
        postStream = topicController.get('postStream');
    postStream.cancelFilter();

    topicController.set('multiSelect', false);
    topicController.unsubscribe();
    this.controllerFor('composer').set('topic', null);
    Discourse.ScreenTrack.current().stop();

    var headerController;
    if (headerController = this.controllerFor('header')) {
      headerController.set('topic', null);
      headerController.set('showExtraInfo', false);
    }
  },

  setupController: function(controller, model) {
    // In case we navigate from one topic directly to another
    this.set("isTransitioning", false);

    if (Discourse.Mobile.mobileView) {
      // close the dropdowns on mobile
      $('.d-dropdown').hide();
      $('header ul.icons li').removeClass('active');
      $('[data-toggle="dropdown"]').parent().removeClass('open');
    }

    controller.setProperties({
      model: model,
      editingTopic: false
    });

    Discourse.TopicRoute.trigger('setupTopicController', this);

    this.controllerFor('header').setProperties({
      topic: model,
      showExtraInfo: false
    });

    this.controllerFor('composer').set('topic', model);
    Discourse.TopicTrackingState.current().trackIncoming('all');
    controller.subscribe();

    this.controllerFor('topic-progress').set('model', model);
    // We reset screen tracking every time a topic is entered
    Discourse.ScreenTrack.current().start(model.get('id'), controller);
  }

});

RSVP.EventTarget.mixin(Discourse.TopicRoute);
