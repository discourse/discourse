import ModalFunctionality from 'discourse/mixins/modal-functionality';
import BufferedContent from 'discourse/mixins/buffered-content';

export default Ember.Controller.extend(ModalFunctionality, BufferedContent, {

  renameDisabled: function() {
    const filterRegexp = new RegExp(this.site.tags_filter_regexp, "g"),
          newId = this.get('buffered.id').replace(filterRegexp, '').trim();

    return (newId.length === 0) || (newId === this.get('model.id'));
  }.property('buffered.id', 'id'),

  actions: {
    performRename() {
      const tag = this.get('model'),
            self = this;
      tag.update({ id: this.get('buffered.id') }).then(function() {
        self.send('closeModal');
        self.transitionToRoute('tags.show', tag.get('id'));
      }).catch(function() {
        self.flash(I18n.t('generic_error'), 'error');
      });
    }
  }
});
