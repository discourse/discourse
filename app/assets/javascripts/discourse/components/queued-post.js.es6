import { propertyEqual } from 'discourse/lib/computed';
import { bufferedProperty } from 'discourse/mixins/buffered-content';
import { popupAjaxError } from 'discourse/lib/ajax-error';

function updateState(state, opts) {
  opts = opts || {};

  return function() {
    const post = this.get('post');
    const args = { state };

    if (opts.deleteUser) { args.delete_user = true; }

    post.update(args).then(() => {
      this.sendAction('removePost', post);
    }).catch(popupAjaxError);
  };
}

export default Ember.Component.extend(bufferedProperty('editables'), {
  editing: propertyEqual('post', 'currentlyEditing'),
  editables: null,
  _confirmDelete: updateState('rejected', {deleteUser: true}),

  _initEditables: function() {
    const post = this.get('post');
    const postOptions = post.get('post_options');

    this.set('editables', {});

    if (post.revised) {
      const changes = postOptions.changes;

      ['raw', 'title', 'tags', 'edit_reason'].forEach(key => {
        if (changes[key] !== undefined) {
          this.set(`editables.${key}`, changes[key]);
        }
      });

      if (changes['category_id'] !== undefined) {
        this.set('editables.category_id', changes['category_id']);
        this.set('editables.category', Discourse.Category.findById(changes['category_id']));
      }
    } else {
      this.set('editables.raw', post.get('raw'));
      this.set('editables.category', post.get('category'));
      this.set('editables.category_id', post.get('category.id'));
      this.set('editables.title', postOptions.title);
      this.set('editables.tags', postOptions.tags);
    }
  }.on('init'),

  _categoryChanged: function() {
    this.set('buffered.category', Discourse.Category.findById(this.get('buffered.category_id')));
  }.observes('buffered.category_id'),

  showEditReason: Ember.computed.notEmpty('editables.edit_reason'),

  editTitleAndCategory: function() {
    return this.get('editing') && !this.get('post.topic');
  }.property('editing'),

  tags: function() {
    return this.get('editables.tags') || this.get('post.topic.tags') || [];
  }.property('editables.tags'),

  showTags: function() {
    return this.siteSettings.tagging_enabled && !this.get('editing') && this.get('tags').length > 0;
  }.property('editing', 'tags'),

  editTags: function() {
    return this.siteSettings.tagging_enabled && this.get('editing') && !this.get('post.topic');
  }.property('editing'),

  actions: {
    approve: updateState('approved'),
    reject: updateState('rejected'),

    displayEditReason() {
      this.set('showEditReason', true);
    },

    deleteUser() {
      bootbox.confirm(I18n.t('queue.delete_prompt', {username: this.get('post.user.username')}), (confirmed) => {
        if (confirmed) { this._confirmDelete(); }
      });
    },

    edit() {
      // This is stupid but pagedown cannot be on the screen twice or it will break
      this.set('currentlyEditing', null);
      Ember.run.scheduleOnce('afterRender', () => this.set('currentlyEditing', this.get('post')));
    },

    confirmEdit() {
      const buffered = this.get('buffered');

      this.get('post').update(buffered.getProperties(
        'raw',
        'title',
        'tags',
        'category_id',
        'edit_reason'
      )).then(() => {
        this.commitBuffer();
        this.set('currentlyEditing', null);
      });
    },

    cancelEdit() {
      this.rollbackBuffer();
      this.set('currentlyEditing', null);
    }
  }
});
