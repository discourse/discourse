import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DatePickerPast from "discourse/components/date-picker-past";
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

  <template>
    <DModal
      @bodyClass="change-timestamp"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @title={{i18n "topic.change_timestamp.title"}}
    >
      <:body>
        <p>
          {{i18n "topic.change_timestamp.instructions"}}
        </p>
        <p class="alert alert-error {{unless this.validTimestamp 'hidden'}}">
          {{i18n "topic.change_timestamp.invalid_timestamp"}}
        </p>
        <form>
          <DatePickerPast
            @value={{readonly this.date}}
            @containerId="date-container"
            @onSelect={{fn (mut this.date)}}
          />
          <Input @type="time" @value={{this.time}} />
        </form>
        <div id="date-container"></div>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @disabled={{this.buttonDisabled}}
          @action={{this.changeTimestamp}}
          @label={{if this.saving "saving" "topic.change_timestamp.action"}}
        />
      </:footer>
    </DModal>
  </template>
}
