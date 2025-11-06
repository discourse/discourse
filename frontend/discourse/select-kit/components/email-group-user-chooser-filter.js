import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import MultiSelectFilterComponent from "select-kit/components/multi-select/multi-select-filter";

@classNames("email-group-user-chooser-filter")
export default class EmailGroupUserChooserFilter extends MultiSelectFilterComponent {
  @action
  onPaste(event) {
    if (this.selectKit.options.maximum === 1) {
      return;
    }

    const data = event?.clipboardData;

    if (!data) {
      return;
    }

    const recipients = [];
    data
      .getData("text")
      .split(/[, \n]+/)
      .forEach((recipient) => {
        recipient = recipient.replace(/^@+/, "").trim();
        if (recipient.length > 0) {
          recipients.push(recipient);
        }
      });

    if (recipients.length > 0) {
      event.stopPropagation();
      event.preventDefault();

      this.selectKit.append(recipients);

      return false;
    }
  }
}
