import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class SiteSettingDefaultCategories extends Component {
  @action
  updateExistingUsers() {
    this.args.model.setUpdateExistingUsers(true);
    this.args.closeModal();
  }

  @action
  cancel() {
    this.args.model.setUpdateExistingUsers(false);
    this.args.closeModal();
  }

  <template>
    <DModal
      @closeModal={{this.cancel}}
      @title={{trustHTML @model.siteSetting.key}}
    >
      <:body>
        {{i18n
          "admin.site_settings.default_categories.modal_description"
          count=@model.siteSetting.count
        }}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.updateExistingUsers}}
          @label="admin.site_settings.default_categories.modal_yes"
        />
        <DButton
          class="btn-default"
          @action={{this.cancel}}
          @label="admin.site_settings.default_categories.modal_no"
        />
      </:footer>
    </DModal>
  </template>
}
