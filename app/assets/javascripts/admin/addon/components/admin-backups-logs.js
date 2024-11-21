import Component from "@ember/component";
import { scheduleOnce } from "@ember/runloop";
import { classNames } from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import discourseDebounce from "discourse-common/lib/debounce";
import { i18n } from "discourse-i18n";

@classNames("admin-backups-logs")
export default class AdminBackupsLogs extends Component {
  showLoadingSpinner = false;
  hasFormattedLogs = false;
  noLogsMessage = i18n("admin.backups.logs.none");
  formattedLogs = "";
  index = 0;

  _reset() {
    this.setProperties({ formattedLogs: "", index: 0 });
  }

  _scrollDown() {
    const div = this.element;
    div.scrollTop = div.scrollHeight;
  }

  @on("init")
  @observes("logs.[]")
  _resetFormattedLogs() {
    if (this.logs.length === 0) {
      this._reset(); // reset the cached logs whenever the model is reset
      this.renderLogs();
    }
  }

  _updateFormattedLogsFunc() {
    const logs = this.logs;
    if (logs.length === 0) {
      return;
    }

    // do the log formatting only once for HELLish performance
    let formattedLogs = this.formattedLogs;
    for (let i = this.index, length = logs.length; i < length; i++) {
      const date = logs[i].get("timestamp"),
        message = logs[i].get("message");
      formattedLogs += "[" + date + "] " + message + "\n";
    }
    // update the formatted logs & cache index
    this.setProperties({
      formattedLogs,
      index: logs.length,
    });
    // force rerender
    this.renderLogs();

    scheduleOnce("afterRender", this, this._scrollDown);
  }

  @on("init")
  @observes("logs.[]")
  _updateFormattedLogs() {
    discourseDebounce(this, this._updateFormattedLogsFunc, 150);
  }

  renderLogs() {
    const formattedLogs = this.formattedLogs;
    if (formattedLogs && formattedLogs.length > 0) {
      this.set("hasFormattedLogs", true);
    } else {
      this.set("hasFormattedLogs", false);
    }
    // add a loading indicator
    if (this.get("status.isOperationRunning")) {
      this.set("showLoadingSpinner", true);
    } else {
      this.set("showLoadingSpinner", false);
    }
  }
}
