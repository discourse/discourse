import AddCategoryClass from 'discourse/mixins/add-category-class';
import AddArchetypeClass from 'discourse/mixins/add-archetype-class';
import ClickTrack from 'discourse/lib/click-track';
import { listenForViewEvent } from 'discourse/lib/app-events';
import { categoryBadgeHTML } from 'discourse/helpers/category-link';
import Scrolling from 'discourse/mixins/scrolling';

const TopicView = Ember.View.extend(AddCategoryClass, AddArchetypeClass, Scrolling, {
  templateName: 'topic',
  topicBinding: 'controller.model',

  userFilters: Ember.computed.alias('controller.model.userFilters'),
  classNameBindings: ['controller.multiSelect:multi-select',
                      'topic.archetype',
                      'topic.is_warning',
                      'topic.category.read_restricted:read_restricted',
                      'topic.deleted:deleted-topic',
                      'topic.categoryClass'],
  menuVisible: true,
  SHORT_POST: 1200,

  categoryFullSlug: Em.computed.alias('topic.category.fullSlug'),

  postStream: Em.computed.alias('controller.model.postStream'),

  archetype: Em.computed.alias('topic.archetype'),

  _composeChanged: function() {
    const composerController = Discourse.get('router.composerController');
    composerController.clearState();
    composerController.set('topic', this.get('topic'));
  }.observes('composer'),

  _enteredTopic: function() {
    // Ember is supposed to only call observers when values change but something
    // in our view set up is firing this observer with the same value. This check
    // prevents scrolled from being called twice.
    const enteredAt = this.get('controller.enteredAt');
    if (enteredAt && (this.get('lastEnteredAt') !== enteredAt)) {
      this.scrolled();
      this.set('lastEnteredAt', enteredAt);
    }
  }.observes('controller.enteredAt'),

  _inserted: function() {
    this.bindScrolling({name: 'topic-view'});

    $(window).on('resize.discourse-on-scroll', () => this.scrolled());

    this.$().on('mouseup.discourse-redirect', '.cooked a, a.track-link', function(e) {
      // bypass if we are selecting stuff
      const selection = window.getSelection && window.getSelection();
      if (selection.type === "Range" || selection.rangeCount > 0) {
        if (Discourse.Utilities.selectedText() !== "") {
          return true;
        }
      }

      const $target = $(e.target);
      if ($target.hasClass('mention') || $target.parents('.expanded-embed').length) { return false; }

      return ClickTrack.trackClick(e);
    });

  }.on('didInsertElement'),

  // This view is being removed. Shut down operations
  _destroyed: function() {
    this.unbindScrolling('topic-view');
    $(window).unbind('resize.discourse-on-scroll');

    // Unbind link tracking
    this.$().off('mouseup.discourse-redirect', '.cooked a, a.track-link');

    this.resetExamineDockCache();

    // this happens after route exit, stuff could have trickled in
    this.set('controller.controllers.header.showExtraInfo', false);

  }.on('willDestroyElement'),

  gotFocus: function() {
    if (Discourse.get('hasFocus')){
      this.scrolled();
    }
  }.observes("Discourse.hasFocus"),

  resetExamineDockCache: function() {
    this.set('docAt', false);
  },

  offset: 0,
  hasScrolled: Em.computed.gt("offset", 0),

  // The user has scrolled the window, or it is finished rendering and ready for processing.
  scrolled() {

    if (this.isDestroyed || this.isDestroying || this._state !== 'inDOM') {
      return;
    }

    const offset = window.pageYOffset || $('html').scrollTop();
    if (!this.get('docAt')) {
      const title = $('#topic-title');
      if (title && title.length === 1) {
        this.set('docAt', title.offset().top);
      }
    }

    this.set("offset", offset);

    const headerController = this.get('controller.controllers.header'),
          topic = this.get('controller.model');
    if (this.get('docAt')) {
      headerController.set('showExtraInfo', offset >= this.get('docAt') || topic.get('postStream.firstPostNotLoaded'));
    } else {
      headerController.set('showExtraInfo', topic.get('postStream.firstPostNotLoaded'));
    }

    // Trigger a scrolled event
    this.appEvents.trigger('topic:scrolled', offset);
  },

  browseMoreMessage: function() {
    var opts = { latestLink: "<a href=\"" + Discourse.getURL("/latest") + "\">" + I18n.t("topic.view_latest_topics") + "</a>" },
        category = this.get('controller.content.category');

    if(category && Em.get(category, 'id') === Discourse.Site.currentProp("uncategorized_category_id")) {
      category = null;
    }

    if (category) {
      opts.catLink = categoryBadgeHTML(category);
    } else {
      opts.catLink = "<a href=\"" + Discourse.getURL("/categories") + "\">" + I18n.t("topic.browse_all_categories") + "</a>";
    }

    const tracking = this.get('topicTrackingState'),
          unreadTopics = tracking.countUnread(),
          newTopics = tracking.countNew();

    if (newTopics + unreadTopics > 0) {
      const hasBoth = unreadTopics > 0 && newTopics > 0;

      return I18n.messageFormat("topic.read_more_MF", {
        "BOTH": hasBoth,
        "UNREAD": unreadTopics,
        "NEW": newTopics,
        "CATEGORY": category ? true : false,
        latestLink: opts.latestLink,
        catLink: opts.catLink
      });
    } else if (category) {
      return I18n.t("topic.read_more_in_category", opts);
    } else {
      return I18n.t("topic.read_more", opts);
    }
  }.property('topicTrackingState.messageCount')
});

function highlight(postNumber) {
  const $contents = $('#post_' + postNumber +' .topic-body'),
        origColor = $contents.data('orig-color') || $contents.css('backgroundColor');

  $contents.data("orig-color", origColor)
    .addClass('highlighted')
    .stop()
    .animate({ backgroundColor: origColor }, 2500, 'swing', function() {
      $contents.removeClass('highlighted');
      $contents.css({'background-color': ''});
    });
}

listenForViewEvent(TopicView, 'post:highlight', function(postNumber) {
  Ember.run.scheduleOnce('afterRender', null, highlight, postNumber);
});

export default TopicView;
