import {
  arrayContentDidChange,
  arrayContentWillChange,
} from "@ember/-internals/metal";
import EmberArray from "@ember/array";
import EmberObject from "@ember/object";
import { trackedArray } from "discourse/lib/tracked-tools";

export function Placeholder(viewName) {
  this.viewName = viewName;
}

export default class PostsWithPlaceholders extends EmberObject.extend(
  EmberArray
) {
  @trackedArray posts = null;
  _appendingIds = {};

  get length() {
    return this.posts.length + Object.keys(this._appendingIds || {}).length;
  }

  nextObject(index) {
    return this.objectAt(index);
  }

  _changeArray(cb, offset, removed, inserted) {
    arrayContentWillChange(this, offset, removed, inserted);
    cb();
    arrayContentDidChange(this, offset, removed, inserted);
    this.notifyPropertyChange("length");
  }

  clear(cb) {
    this._changeArray(cb, 0, this.posts.length, 0);
  }

  appendPost(cb) {
    this._changeArray(cb, this.posts.length, 0, 1);
  }

  removePost(cb) {
    this._changeArray(cb, this.posts.length - 1, 1, 0);
  }

  insertPost(insertAtIndex, cb) {
    this._changeArray(cb, insertAtIndex, 0, 1);
  }

  refreshAll(cb) {
    const length = this.posts.length;
    this._changeArray(cb, 0, length, length);
  }

  appending(postIds) {
    this._changeArray(
      () => {
        const appendingIds = this._appendingIds;
        postIds.forEach((pid) => (appendingIds[pid] = true));
      },
      this.length,
      0,
      postIds.length
    );
  }

  finishedAppending(postIds) {
    this._changeArray(
      () => {
        const appendingIds = this._appendingIds;
        postIds.forEach((pid) => delete appendingIds[pid]);
      },
      this.posts.length - postIds.length,
      postIds.length,
      postIds.length
    );
  }

  finishedPrepending(postIds) {
    this._changeArray(function () {}, 0, 0, postIds.length);
  }

  objectAt(index) {
    const posts = this.posts;
    return index < posts.length
      ? posts[index]
      : new Placeholder("post-placeholder");
  }
}
