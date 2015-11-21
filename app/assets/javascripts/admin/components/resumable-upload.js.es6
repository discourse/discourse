/*global Resumable:true */

/**
  Example usage:

    {{resumable-upload
        target="/admin/backups/upload"
        success="successAction"
        error="errorAction"
        uploadText="UPLOAD"
    }}
**/
const ResumableUploadComponent = Ember.Component.extend(Discourse.StringBuffer, {
  tagName: "button",
  classNames: ["btn", "ru"],
  classNameBindings: ["isUploading"],
  attributeBindings: ["translatedTitle:title"],

  resumable: null,

  isUploading: false,
  progress: 0,

  rerenderTriggers: ['isUploading', 'progress'],

  translatedTitle: function() {
    const title = this.get('title');
    return title ? I18n.t(title) : this.get('text');
  }.property('title', 'text'),

  text: function() {
    if (this.get("isUploading")) {
      return this.get("progress") + " %";
    } else {
      return this.get("uploadText");
    }
  }.property("isUploading", "progress"),

  renderString: function(buffer) {
    var icon = this.get("isUploading") ? "times" : "upload";
    buffer.push("<i class='fa fa-" + icon + "'></i>");
    buffer.push("<span class='ru-label'>" + this.get("text") + "</span>");
    buffer.push("<span class='ru-progress' style='width:" + this.get("progress") + "%'></span>");
  },

  click: function() {
    if (this.get("isUploading")) {
      this.resumable.cancel();
      var self = this;
      Em.run.later(function() { self._reset(); });
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
      target: this.get("target"),
      maxFiles: 1, // only 1 file at a time
      headers: { "X-CSRF-Token": $("meta[name='csrf-token']").attr("content") }
    });

    var self = this;

    this.resumable.on("fileAdded", function() {
      // automatically upload the selected file
      self.resumable.upload();
      // mark as uploading
      Em.run.later(function() {
        self.set("isUploading", true);
      });
    });

    this.resumable.on("fileProgress", function(file) {
      // update progress
      Em.run.later(function() {
        self.set("progress", parseInt(file.progress() * 100, 10));
      });
    });

    this.resumable.on("fileSuccess", function(file) {
      Em.run.later(function() {
        // mark as not uploading anymore
        self._reset();
        // fire an event to allow the parent route to reload its model
        self.sendAction("success", file.fileName);
      });
    });

    this.resumable.on("fileError", function(file, message) {
      Em.run.later(function() {
        // mark as not uploading anymore
        self._reset();
        // fire an event to allow the parent route to display the error message
        self.sendAction("error", file.fileName, message);
      });
    });

  }.on("init"),

  _assignBrowse: function() {
    var self = this;
    Em.run.schedule("afterRender", function() {
      self.resumable.assignBrowse(self.$());
    });
  }.on("didInsertElement"),

  _teardown: function() {
    if (this.resumable) {
      this.resumable.cancel();
      this.resumable = null;
    }
  }.on("willDestroyElement")

});

export default ResumableUploadComponent;
