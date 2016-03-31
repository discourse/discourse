import { default as computed } from 'ember-addons/ember-computed-decorators';

export function Placeholder(viewName) {
  this.viewName = viewName;
}

export default Ember.Object.extend(Ember.Array, {
  posts: null,
  _appendingIds: null,

  init() {
    this._appendingIds = {};
  },

  @computed
  length() {
    return this.get('posts.length') + Object.keys(this._appendingIds || {}).length;
  },

  _changeArray(cb, offset, removed, inserted) {
    this.arrayContentWillChange(offset, removed, inserted);
    cb();
    this.arrayContentDidChange(offset, removed, inserted);
    this.propertyDidChange('length');
  },

  clear(cb) {
    this._changeArray(cb, 0, this.get('posts.length'), 0);
  },

  appendPost(cb) {
    this._changeArray(cb, this.get('posts.length'), 0, 1);
  },

  removePost(cb) {
    this._changeArray(cb, this.get('posts.length') - 1, 1, 0);
  },

  refreshAll(cb) {
    const length = this.get('posts.length');
    this._changeArray(cb, 0, length, length);
  },

  appending(postIds) {
    this._changeArray(() => {
      const appendingIds = this._appendingIds;
      postIds.forEach(pid => appendingIds[pid] = true);
    }, this.get('length'), 0, postIds.length);
  },

  finishedAppending(postIds) {
    this._changeArray(() => {
      const appendingIds = this._appendingIds;
      postIds.forEach(pid => delete appendingIds[pid]);
    }, this.get('posts.length') - postIds.length, postIds.length, postIds.length);
  },

  finishedPrepending(postIds) {
    this._changeArray(Ember.K, 0, 0, postIds.length);
  },

  objectAt(index) {
    const posts = this.get('posts');
    return (index < posts.length) ? posts[index] : new Placeholder('post-placeholder');
  },
});
