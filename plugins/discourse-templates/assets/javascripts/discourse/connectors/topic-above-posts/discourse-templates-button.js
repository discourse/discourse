import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";
import discourseDebounce from "discourse-common/lib/debounce";

export default class DiscourseTemplatesButton extends Component {
  static shouldRender(outletArgs, helper) {
    return outletArgs.model.is_template && helper.currentUser?.can_create_topic;
  }

  @service composer;
  @tracked copyConfirm = false;

  async fetchRaw() {
    const topic = this.args.outletArgs.model;
    return await ajax(`/raw/${topic.id}/1`, { dataType: "text" });
  }

  @action
  async createNewTopic() {
    const text = await this.fetchRaw();
    this.composer.openNewTopic({
      body: text,
    });
  }

  @action
  async copy() {
    const text = await this.fetchRaw();
    navigator.clipboard.writeText(text);
    this.copyConfirm = true;
    discourseDebounce(this.resetCopyButton, 2000);
  }

  @action
  resetCopyButton() {
    this.copyConfirm = false;
  }
}
