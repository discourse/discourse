import { schedule } from "@ember/runloop";
import { later } from "@ember/runloop";
import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import discourseComputed, { on } from "discourse-common/utils/decorators";

/*global Resumable:true */

/**
  Example usage:

    {{resumable-upload
        target="/admin/backups/upload"
        success=(action "successAction")
        error=(action "errorAction")
        uploadText="UPLOAD"
    }}
**/
export default Component.extend({
  tagName: "button",
  classNames: ["btn", "ru"],
  classNameBindings: ["isUploading"],
  attributeBindings: ["translatedTitle:title"],
  resumable: null,
  isUploading: false,
  progress: 0,
  rerenderTriggers: ["isUploading", "progress"],
  uploadingIcon: null,
  progressBar: null,

  @on("init")
  _initialize() {
    this.resumable = new Resumable({
      target: Discourse.getURL(this.target),
      maxFiles: 1, // only 1 file at a time
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")
          .content
      }
    });

    this.resumable.on("fileAdded", () => {
      // automatically upload the selected file
      this.resumable.upload();

      // mark as uploading
      later(() => {
        this.set("isUploading", true);
        this._updateIcon();
      });
    });

    this.resumable.on("fileProgress", file => {
      // update progress
      later(() => {
        this.set("progress", parseInt(file.progress() * 100, 10));
        this._updateProgressBar();
      });
    });

    this.resumable.on("fileSuccess", file => {
      later(() => {
        // mark as not uploading anymore
        this._reset();

        // fire an event to allow the parent route to reload its model
        this.success(file.fileName);
      });
    });

    this.resumable.on("fileError", (file, message) => {
      later(() => {
        // mark as not uploading anymore
        this._reset();

        // fire an event to allow the parent route to display the error message
        this.error(file.fileName, message);
      });
    });
  },

  @on("didInsertElement")
  _assignBrowse() {
    schedule("afterRender", () => this.resumable.assignBrowse($(this.element)));
  },

  @on("willDestroyElement")
  _teardown() {
    if (this.resumable) {
      this.resumable.cancel();
      this.resumable = null;
    }
  },

  @discourseComputed("title", "text")
  translatedTitle(title, text) {
    return title ? I18n.t(title) : text;
  },

  @discourseComputed("isUploading", "progress")
  text(isUploading, progress) {
    if (isUploading) {
      return progress + " %";
    } else {
      return this.uploadText;
    }
  },

  didReceiveAttrs() {
    this._super(...arguments);
    this._updateIcon();
  },

  click() {
    if (this.isUploading) {
      this.resumable.cancel();
      later(() => this._reset());
      return false;
    } else {
      return true;
    }
  },

  _updateIcon() {
    const icon = this.isUploading ? "times" : "upload";
    this.set("uploadingIcon", `${iconHTML(icon)}`.htmlSafe());
  },

  _updateProgressBar() {
    const pb = `${"width:" + this.progress + "%"}`.htmlSafe();
    this.set("progressBar", pb);
  },

  _reset() {
    this.setProperties({ isUploading: false, progress: 0 });
    this._updateIcon();
    this._updateProgressBar();
  }
});
