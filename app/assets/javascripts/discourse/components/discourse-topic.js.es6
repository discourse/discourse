import AddArchetypeClass from 'discourse/mixins/add-archetype-class';
import ClickTrack from 'discourse/lib/click-track';
import Scrolling from 'discourse/mixins/scrolling';
import { selectedText } from 'discourse/lib/utilities';
import { observes } from 'ember-addons/ember-computed-decorators';

function highlight(postNumber) {
  const $contents = $(`#post_${postNumber} .topic-body`);

  $contents.addClass('highlighted');
  $contents.on('animationend', () => $contents.removeClass('highlighted'));
}

export default Ember.Component.extend(AddArchetypeClass, Scrolling, {
  userFilters: Ember.computed.alias('topic.userFilters'),
  classNameBindings: ['multiSelect',
                      'topic.archetype',
                      'topic.is_warning',
                      'topic.category.read_restricted:read_restricted',
                      'topic.deleted:deleted-topic',
                      'topic.categoryClass'],
  menuVisible: true,
  SHORT_POST: 1200,

  postStream: Ember.computed.alias('topic.postStream'),
  archetype: Ember.computed.alias('topic.archetype'),

  _lastShowTopic: null,

  @observes('enteredAt')
  _enteredTopic() {
    // Ember is supposed to only call observers when values change but something
    // in our view set up is firing this observer with the same value. This check
    // prevents scrolled from being called twice.
    const enteredAt = this.get('enteredAt');
    if (enteredAt && (this.get('lastEnteredAt') !== enteredAt)) {
      this._lastShowTopic = null;
      this.scrolled();
      this.set('lastEnteredAt', enteredAt);
    }
  },

  didInsertElement() {
    this._super();
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
  },

  willDestroyElement() {
    this._super();
    this.unbindScrolling('topic-view');
    $(window).unbind('resize.discourse-on-scroll');

    // Unbind link tracking
    this.$().off('mouseup.discourse-redirect', '.cooked a, a.track-link');

    this.resetExamineDockCache();

    // this happens after route exit, stuff could have trickled in
    this.appEvents.trigger('header:hide-topic');
    this.appEvents.off('post:highlight');

  },

  @observes('Discourse.hasFocus')
  gotFocus() {
    if (Discourse.get('hasFocus')){
      this.scrolled();
    }
  },

  resetExamineDockCache() {
    this.set('docAt', false);
  },

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

    this.set('hasScrolled', offset > 0);

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
