import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";
import {
  default as computed,
  on
} from "ember-addons/ember-computed-decorators";

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
export default Component.extend(
  bufferedRender({
    tagName: "button",
    classNames: ["btn", "ru"],
    classNameBindings: ["isUploading"],
    attributeBindings: ["translatedTitle:title"],
    resumable: null,
    isUploading: false,
    progress: 0,
    rerenderTriggers: ["isUploading", "progress"],

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
        Ember.run.later(() => this.set("isUploading", true));
      });

      this.resumable.on("fileProgress", file => {
        // update progress
        Ember.run.later(() =>
          this.set("progress", parseInt(file.progress() * 100, 10))
        );
      });

      this.resumable.on("fileSuccess", file => {
        Ember.run.later(() => {
          // mark as not uploading anymore
          this._reset();

          // fire an event to allow the parent route to reload its model
          this.success(file.fileName);
        });
      });

      this.resumable.on("fileError", (file, message) => {
        Ember.run.later(() => {
          // mark as not uploading anymore
          this._reset();

          // fire an event to allow the parent route to display the error message
          this.error(file.fileName, message);
        });
      });
    },

    @on("didInsertElement")
    _assignBrowse() {
      Ember.run.schedule("afterRender", () =>
        this.resumable.assignBrowse($(this.element))
      );
    },

    @on("willDestroyElement")
    _teardown() {
      if (this.resumable) {
        this.resumable.cancel();
        this.resumable = null;
      }
    },

    @computed("title", "text")
    translatedTitle(title, text) {
      return title ? I18n.t(title) : text;
    },

    @computed("isUploading", "progress")
    text(isUploading, progress) {
      if (isUploading) {
        return progress + " %";
      } else {
        return this.uploadText;
      }
    },

    buildBuffer(buffer) {
      const icon = this.isUploading ? "times" : "upload";
      buffer.push(iconHTML(icon));
      buffer.push("<span class='ru-label'>" + this.text + "</span>");
      buffer.push(
        "<span class='ru-progress' style='width:" + this.progress + "%'></span>"
      );
    },

    click() {
      if (this.isUploading) {
        this.resumable.cancel();
        Ember.run.later(() => this._reset());
        return false;
      } else {
        return true;
      }
    },

    _reset() {
      this.setProperties({ isUploading: false, progress: 0 });
    }
  })
);
