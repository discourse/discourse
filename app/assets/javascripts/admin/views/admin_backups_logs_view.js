Discourse.AdminBackupsLogsView = Discourse.View.extend({

  classNames: ["admin-backups-logs"],

  _initialize: function() { this._reset(); }.on("init"),

  _reset: function() {
    this.setProperties({ formattedLogs: "", index: 0 });
  },

  _updateFormattedLogs: function() {
    var logs = this.get("controller.model");
    if (logs.length === 0) {
      this._reset(); // reset the cached logs whenever the model is reset
    } else {
      // do the log formatting only once for HELLish performance
      var formattedLogs = this.get("formattedLogs");
      for (var i = this.get("index"), length = logs.length; i < length; i++) {
        var date = moment(logs[i].get("timestamp")).format("YYYY-MM-DD HH:mm:ss"),
            message = Handlebars.Utils.escapeExpression(logs[i].get("message"));
        formattedLogs += "[" + date + "] " + message + "\n";
      }
      // update the formatted logs & cache index
      this.setProperties({ formattedLogs: formattedLogs, index: logs.length });
      // force rerender
      this.rerender();
    }
  }.observes("controller.model.@each"),

  render: function(buffer) {
    var formattedLogs = this.get("formattedLogs");
    if (formattedLogs && formattedLogs.length > 0) {
      buffer.push("<pre>");
      buffer.push(formattedLogs);
      buffer.push("</pre>");
    } else {
      buffer.push("<p>" + I18n.t("admin.backups.logs.none") + "</p>");
    }
    // add a loading indicator
    if (this.get("controller.status.isOperationRunning")) {
      buffer.push("<i class='fa fa-spinner fa-spin'></i>");
    }
  },

  _forceScrollToBottom: function() {
    var $div = this.$()[0];
    $div.scrollTop = $div.scrollHeight;
  }.on("didInsertElement")

});
