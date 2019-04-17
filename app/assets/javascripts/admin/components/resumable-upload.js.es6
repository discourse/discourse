import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";
import computed from "ember-addons/ember-computed-decorators";

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
export default Ember.Component.extend(
  bufferedRender({
    tagName: "button",
    classNames: ["btn", "ru"],
    classNameBindings: ["isUploading"],
    attributeBindings: ["translatedTitle:title"],

    resumable: null,

    isUploading: false,
    progress: 0,

    rerenderTriggers: ["isUploading", "progress"],

    @computed("title", "text")
    translatedTitle(title, text) {
      return title ? I18n.t(title) : text;
    },

    @computed("isUploading", "progress")
    text(isUploading, progress) {
      if (isUploading) {
        return progress + " %";
      } else {
        return this.get("uploadText");
      }
    },

    buildBuffer(buffer) {
      const icon = this.get("isUploading") ? "times" : "upload";
      buffer.push(iconHTML(icon));
      buffer.push("<span class='ru-label'>" + this.get("text") + "</span>");
      buffer.push(
        "<span class='ru-progress' style='width:" +
          this.get("progress") +
          "%'></span>"
      );
    },

    click: function() {
      if (this.get("isUploading")) {
        this.resumable.cancel();
        var self = this;
        Ember.run.later(function() {
          self._reset();
        });
        return false;
      } else {
        return true;
      }
    },

    _reset: function() {
      this.setProperties({ isUploading: false, progress: 0 });
    },

    _initialize: function() {
      this.resumable = new Resumable({
        target: Discourse.getURL(this.get("target")),
        maxFiles: 1, // only 1 file at a time
        headers: {
          "X-CSRF-Token": $("meta[name='csrf-token']").attr("content")
        }
      });

      var self = this;

      this.resumable.on("fileAdded", function() {
        // automatically upload the selected file
        self.resumable.upload();
        // mark as uploading
        Ember.run.later(function() {
          self.set("isUploading", true);
        });
      });

      this.resumable.on("fileProgress", function(file) {
        // update progress
        Ember.run.later(function() {
          self.set("progress", parseInt(file.progress() * 100, 10));
        });
      });

      this.resumable.on("fileSuccess", function(file) {
        Ember.run.later(function() {
          // mark as not uploading anymore
          self._reset();
          // fire an event to allow the parent route to reload its model
          self.success(file.fileName);
        });
      });

      this.resumable.on("fileError", function(file, message) {
        Ember.run.later(function() {
          // mark as not uploading anymore
          self._reset();
          // fire an event to allow the parent route to display the error message
          self.error(file.fileName, message);
        });
      });
    }.on("init"),

    _assignBrowse: function() {
      var self = this;
      Ember.run.schedule("afterRender", function() {
        self.resumable.assignBrowse(self.$());
      });
    }.on("didInsertElement"),

    _teardown: function() {
      if (this.resumable) {
        this.resumable.cancel();
        this.resumable = null;
      }
    }.on("willDestroyElement")
  })
);
