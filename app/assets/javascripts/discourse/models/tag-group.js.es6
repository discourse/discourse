import { ajax } from 'discourse/lib/ajax';
import RestModel from 'discourse/models/rest';
import computed from 'ember-addons/ember-computed-decorators';
import PermissionType from 'discourse/models/permission-type';

const TagGroup = RestModel.extend({
  @computed('name', 'tag_names')
  disableSave() {
    return Ember.isEmpty(this.get('name')) || Ember.isEmpty(this.get('tag_names')) || this.get('saving');
  },

  @computed('permissions')
  permissionName: {
    get(permissions) {
      if (!permissions) return 'public';

      if (permissions['everyone'] === PermissionType.FULL) {
        return 'public';
      } else if (permissions['everyone'] === PermissionType.READONLY) {
        return 'visible';
      } else {
        return 'private';
      }
    },

    set(value) {
      if (value === 'private') {
        this.set('permissions', {'staff': PermissionType.FULL});
      } else if (value === 'visible') {
        this.set('permissions', {'staff': PermissionType.FULL, 'everyone': PermissionType.READONLY});
      } else {
        this.set('permissions', {'everyone': PermissionType.FULL});
      }
    }
  },

  save() {
    let url = "/tag_groups";
    const self = this,
          isNew = this.get('id') === 'new';
    if (!isNew) {
      url = "/tag_groups/" + this.get('id');
    }

    this.set('savingStatus', I18n.t('saving'));
    this.set('saving', true);

    return ajax(url, {
      data: {
        name: this.get('name'),
        tag_names: this.get('tag_names'),
        parent_tag_name: this.get('parent_tag_name') ? this.get('parent_tag_name') : undefined,
        one_per_topic: this.get('one_per_topic'),
        permissions: this.get('permissions')
      },
      type: isNew ? 'POST' : 'PUT'
    }).then(function(result) {
      if(result.tag_group && result.tag_group.id) {
        self.set('id', result.tag_group.id);
      }
      self.set('savingStatus', I18n.t('saved'));
      self.set('saving', false);
    });
  },

  destroy() {
    return ajax("/tag_groups/" + this.get('id'), {type: "DELETE"});
  }
});

export default TagGroup;
