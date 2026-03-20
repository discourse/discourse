import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

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

  <template>
    <div class="template-topic-controls">
      <DButton
        @icon={{if this.copyConfirm "check" "copy"}}
        @action={{this.copy}}
        @label="templates.copy"
        class={{dConcatClass
          "btn-default"
          "template-copy"
          (if this.copyConfirm "ok")
        }}
      />
      <DButton
        @action={{this.createNewTopic}}
        @label="templates.new_topic"
        @icon="plus"
        class="template-new-topic"
      />
    </div>
  </template>
}
