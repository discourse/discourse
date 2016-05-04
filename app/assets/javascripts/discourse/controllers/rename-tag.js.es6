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
      tag.update({ id: this.get('buffered.id') }).then(function(result) {
        self.send('closeModal');
        if (result.responseJson.tag) {
          self.transitionToRoute('tags.show', result.responseJson.tag.id);
        } else {
          self.flash(result.responseJson.errors || I18n.t('generic_error'), 'error');
        }
      }).catch(function(e) {
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
          self.flash(e.jqXHR.responseJSON.errors[0], 'error');
        } else {
          self.flash(I18n.t('generic_error'), 'error');
        }
      });
    }
  }
});
