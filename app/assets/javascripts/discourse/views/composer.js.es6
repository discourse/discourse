import afterTransition from 'discourse/lib/after-transition';
import positioningWorkaround from 'discourse/lib/safari-hacks';
import { headerHeight } from 'discourse/components/site-header';
import { default as computed, on, observes } from 'ember-addons/ember-computed-decorators';
import Composer from 'discourse/models/composer';

const ComposerView = Ember.View.extend({
  _lastKeyTimeout: null,
  elementId: 'reply-control',
  classNameBindings: ['composer.creatingPrivateMessage:private-message',
                      'composeState',
                      'composer.loading',
                      'composer.canEditTitle:edit-title',
                      'composer.createdPost:created-post',
                      'composer.creatingTopic:topic'],

  composer: Em.computed.alias('controller.model'),

  @computed('composer.composeState')
  composeState(composeState) {
    return composeState || Composer.CLOSED;
  },

  movePanels(sizePx) {

    $('#main-outlet').css('padding-bottom', sizePx);

    // signal the progress bar it should move!
    this.appEvents.trigger("composer:resized");
  },

  @observes('composeState', 'composer.action')
  resize() {
    Ember.run.scheduleOnce('afterRender', () => {
      const h = $('#reply-control').height() || 0;
      this.movePanels(h + "px");

      // Figure out the size of the fields
      const $fields = this.$('.composer-fields');
      const fieldPos = $fields.position();
      if (fieldPos) {
        this.$('.wmd-controls').css('top', $fields.height() + fieldPos.top + 5);
      }

      // get the submit panel height
      const submitPos = this.$('.submit-panel').position();
      if (submitPos) {
        this.$('.wmd-controls').css('bottom', h - submitPos.top + 7);
      }
    });
  },

  keyUp() {
    const controller = this.get('controller');
    controller.checkReplyLength();

    this.get('composer').typing();

    const lastKeyUp = new Date();
    this._lastKeyUp = lastKeyUp;

    // One second from now, check to see if the last key was hit when
    // we recorded it. If it was, the user paused typing.
    Ember.run.cancel(this._lastKeyTimeout);
    this._lastKeyTimeout = Ember.run.later(() => {
      if (lastKeyUp !== this._lastKeyUp) { return; }

      // Search for similar topics if the user pauses typing
      controller.findSimilarTopics();
    }, 1000);
  },

  keyDown(e) {
    if (e.which === 27) {
      this.get('controller').send('hitEsc');
      return false;
    } else if (e.which === 13 && (e.ctrlKey || e.metaKey)) {
      // CTRL+ENTER or CMD+ENTER
      this.get('controller').send('save');
      return false;
    }
  },

  @on('didInsertElement')
  _enableResizing() {
    const $replyControl = $('#reply-control');
    const resize = () => Ember.run(() => this.resize());

    $replyControl.DivResizer({
      resize,
      maxHeight: winHeight => winHeight - headerHeight(),
      onDrag: sizePx => this.movePanels(sizePx)
    });

    afterTransition($replyControl, () => {
      resize();
      if (this.get('composer.composeState') === Composer.OPEN) {
        this.appEvents.trigger('composer:opened');
      }
    });
    positioningWorkaround(this.$());
  },

  click() {
    this.get('controller').send('openIfDraft');
  }
});

RSVP.EventTarget.mixin(ComposerView);
export default ComposerView;
