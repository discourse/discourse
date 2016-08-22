import AddCategoryClass from 'discourse/mixins/add-category-class';
import AddArchetypeClass from 'discourse/mixins/add-archetype-class';
import ClickTrack from 'discourse/lib/click-track';
import Scrolling from 'discourse/mixins/scrolling';
import { selectedText } from 'discourse/lib/utilities';

const TopicView = Ember.View.extend(AddCategoryClass, AddArchetypeClass, Scrolling, {
  templateName: 'topic',
  topic: Ember.computed.alias('controller.model'),

  userFilters: Ember.computed.alias('topic.userFilters'),
  classNameBindings: ['controller.multiSelect:multi-select',
                      'topic.archetype',
                      'topic.is_warning',
                      'topic.category.read_restricted:read_restricted',
                      'topic.deleted:deleted-topic',
                      'topic.categoryClass'],
  menuVisible: true,
  SHORT_POST: 1200,

  categoryFullSlug: Em.computed.alias('topic.category.fullSlug'),
  postStream: Em.computed.alias('topic.postStream'),
  archetype: Em.computed.alias('topic.archetype'),

  _lastShowTopic: null,

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
      this._lastShowTopic = null;
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
        if (selectedText() !== "") {
          return true;
        }
      }

      const $target = $(e.target);
      if ($target.hasClass('mention') || $target.parents('.expanded-embed').length) { return false; }

      return ClickTrack.trackClick(e);
    });

    this.appEvents.on('post:highlight', postNumber => {
      Ember.run.scheduleOnce('afterRender', null, highlight, postNumber);
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
    this.appEvents.trigger('header:hide-topic');
    this.appEvents.off('post:highlight');

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

  showTopicInHeader(topic, offset) {
    if (this.get('docAt')) {
      return offset >= this.get('docAt') || topic.get('postStream.firstPostNotLoaded');
    } else {
      return topic.get('postStream.firstPostNotLoaded');
    }
  },

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

    const topic = this.get('topic');
    const showTopic = this.showTopicInHeader(topic, offset);
    if (showTopic !== this._lastShowTopic) {
      this._lastShowTopic = showTopic;

      if (showTopic) {
        this.appEvents.trigger('header:show-topic', topic);
      } else {
        this.appEvents.trigger('header:hide-topic');
      }
    }

    // Trigger a scrolled event
    this.appEvents.trigger('topic:scrolled', offset);
  }
});

function highlight(postNumber) {
  const $contents = $(`#post_${postNumber} .topic-body`),
        origColor = $contents.data('orig-color') || $contents.css('backgroundColor');

  $contents.data("orig-color", origColor)
    .addClass('highlighted')
    .stop()
    .animate({ backgroundColor: origColor }, 2500, 'swing', function() {
      $contents.removeClass('highlighted');
      $contents.css({'background-color': ''});
    });
}

export default TopicView;
