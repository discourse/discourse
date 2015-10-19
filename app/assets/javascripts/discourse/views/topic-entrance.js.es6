import CleansUp from 'discourse/mixins/cleans-up';

export default Ember.View.extend(CleansUp, {
  elementId: 'topic-entrance',
  classNameBindings: ['visible::hidden'],
  visible: Em.computed.notEmpty('controller.model'),

  _positionChanged: function() {
    const pos = this.get('controller.position');
    if (!pos) { return; }

    const $self = this.$();

    // Move after we render so the height is correct
    Em.run.schedule('afterRender', function() {
      const width = $self.width(),
          height = $self.height();
      pos.left = (parseInt(pos.left) - (width / 2));
      pos.top = (parseInt(pos.top) - (height / 2));

      const windowWidth = $(window).width();
      if (pos.left + width > windowWidth) {
        pos.left = (windowWidth - width) - 15;
      }
      $self.css(pos);
    });

    $('html').off('mousedown.topic-entrance').on('mousedown.topic-entrance', e => {
      const $target = $(e.target);
      if (($target.prop('id') === 'topic-entrance') || ($self.has($target).length !== 0)) {
        return;
      }
      this.cleanUp();
    });
  }.observes('controller.position'),

  _removed: function() {
    $('html').off('mousedown.topic-entrance');
  }.on('willDestroyElement'),

  cleanUp() {
    this.set('controller.model', null);
    $('html').off('mousedown.topic-entrance');
  },

  keyDown(e) {
    if (e.which === 27) {
      this.cleanUp();
    }
  }

});
