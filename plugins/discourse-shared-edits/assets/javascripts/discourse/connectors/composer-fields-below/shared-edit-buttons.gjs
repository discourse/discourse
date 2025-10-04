import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class SharedEditButtons extends Component {
  @service composer;
  @service site;

  @action
  endSharedEdit() {
    this.composer.close();
  }

  <template>
    {{#if @outletArgs.model.creatingSharedEdit}}
      <div class="leave-shared-edit">
        <DButton
          @action={{this.endSharedEdit}}
          @icon={{if this.site.mobileView "xmark"}}
          @label={{if this.site.desktopView "shared_edits.done"}}
          title={{if this.site.mobileView (i18n "shared_edits.done")}}
          class={{if this.site.mobileView "btn-transparent" "btn-primary"}}
        />
      </div>
    {{/if}}
  </template>
}
