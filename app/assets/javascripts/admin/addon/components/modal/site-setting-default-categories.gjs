import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import htmlSafe from "discourse/helpers/html-safe";
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
      class="incoming-emails"
      @title={{htmlSafe @model.siteSetting.key}}
      @closeModal={{this.cancel}}
    >
      <:body>
        {{i18n
          "admin.site_settings.default_categories.modal_description"
          count=@model.siteSetting.count
        }}
      </:body>
      <:footer>
        <DButton
          @action={{this.updateExistingUsers}}
          class="btn-primary"
          @label="admin.site_settings.default_categories.modal_yes"
        />
        <DButton
          @action={{this.cancel}}
          @label="admin.site_settings.default_categories.modal_no"
        />
      </:footer>
    </DModal>
  </template>
}
