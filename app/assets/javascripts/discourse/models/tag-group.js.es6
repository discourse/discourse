import { ajax } from 'discourse/lib/ajax';
import RestModel from 'discourse/models/rest';
import computed from 'ember-addons/ember-computed-decorators';

const TagGroup = RestModel.extend({
  @computed('name', 'tag_names')
  disableSave() {
    return Ember.isEmpty(this.get('name')) || Ember.isEmpty(this.get('tag_names')) || this.get('saving');
  },

  save() {
    var url = "/tag_groups",
        self = this;
    if (this.get('id')) {
      url = "/tag_groups/" + this.get('id');
    }

    this.set('savingStatus', I18n.t('saving'));
    this.set('saving', true);

    return ajax(url, {
      data: {
        name: this.get('name'),
        tag_names: this.get('tag_names'),
        parent_tag_name: this.get('parent_tag_name') ? this.get('parent_tag_name') : undefined,
        one_per_topic: this.get('one_per_topic')
      },
      type: this.get('id') ? 'PUT' : 'POST'
    }).then(function(result) {
      if(result.id) { self.set('id', result.id); }
      self.set('savingStatus', I18n.t('saved'));
      self.set('saving', false);
    });
  },

  destroy() {
    return ajax("/tag_groups/" + this.get('id'), {type: "DELETE"});
  }
});

export default TagGroup;
