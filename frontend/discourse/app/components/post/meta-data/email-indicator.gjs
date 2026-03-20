import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class PostMetaDataEmailIndicator extends Component {
  @service currentUser;

  get canViewRawEmail() {
    return this.currentUser?.can_view_raw_email;
  }

  get icon() {
    return this.args.post.is_auto_generated ? "envelope" : "far-envelope";
  }

  get title() {
    return this.args.post.is_auto_generated
      ? i18n("post.via_auto_generated_email")
      : i18n("post.via_email");
  }

  @action
  onShowRawEmail() {
    if (this.canViewRawEmail) {
      this.args.showRawEmail();
    }
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class={{dConcatClass
        "post-info"
        "via-email"
        (if this.canViewRawEmail "raw-email")
      }}
      title={{this.title}}
      {{on "click" this.onShowRawEmail}}
    >
      {{dIcon this.icon}}
    </div>
  </template>
}
