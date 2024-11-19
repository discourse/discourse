import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { isEmpty } from "@ember/utils";
import DiscourseURL from "discourse/lib/url";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";

// Modal related to changing the timestamp of posts
export default class ChangeTimestamp extends Component {
  @tracked saving = false;
  @tracked date = moment().format("YYYY-MM-DD");
  @tracked time;
  @tracked flash;

  get createdAt() {
    return moment(`${this.date} ${this.time}`, "YYYY-MM-DD HH:mm:ss");
  }

  get validTimestamp() {
    return moment().diff(this.createdAt, "minutes") < 0;
  }

  get buttonDisabled() {
    return this.saving || this.validTimestamp || isEmpty(this.date);
  }

  @action
  async changeTimestamp() {
    this.saving = true;
    try {
      await Topic.changeTimestamp(
        this.args.model.topic.id,
        this.createdAt.unix()
      );
      this.args.closeModal();
      next(() => DiscourseURL.routeTo(this.args.model.topic.url));
    } catch {
      this.flash = i18n("topic.change_timestamp.error");
    } finally {
      this.saving = false;
    }
  }
}
