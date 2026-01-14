import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";

export default class CategoryReadOnlyBanner extends Component {
  @service currentUser;

  get shouldShow() {
    return (
      this.args.category?.read_only_banner &&
      this.args.readOnly &&
      this.currentUser
    );
  }

  <template>
    {{#if this.shouldShow}}
      <div class="row">
        <div class="alert alert-info category-read-only-banner">
          {{htmlSafe @category.read_only_banner}}
        </div>
      </div>
    {{/if}}
  </template>
}
