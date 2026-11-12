import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { sanitize } from "discourse/lib/text";

export default class CategoryReadOnlyBanner extends Component {
  @service currentUser;

  get shouldShow() {
    return (
      this.args.category?.read_only_banner &&
      this.args.readOnly &&
      this.currentUser
    );
  }

  get readOnlyBanner() {
    return trustHTML(sanitize(this.args.category.read_only_banner));
  }

  <template>
    {{#if this.shouldShow}}
      <div class="row">
        <div class="alert alert-info category-read-only-banner">
          {{this.readOnlyBanner}}
        </div>
      </div>
    {{/if}}
  </template>
}
