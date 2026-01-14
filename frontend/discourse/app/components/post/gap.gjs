import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class PostGap extends Component {
  @service appEvents;

  @tracked loading = false;

  get label() {
    return this.loading
      ? i18n("loading")
      : i18n("post.gap", { count: this.args.gap.length });
  }

  @action
  async fillGap() {
    if (this.loading) {
      return;
    }
    this.loading = true;

    try {
      await this.args.fillGap();

      this.appEvents.trigger("post-stream:gap-expanded", {
        post_id: this.args.post.id,
      });
    } finally {
      this.loading = false;
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div class="gap" {{on "click" this.fillGap}}>
      {{this.label}}
    </div>
  </template>
}
