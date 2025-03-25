import Component from "@glimmer/component";
import { action } from "@ember/object";

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
}

<DModal
  class="incoming-emails"
  @title={{html-safe @model.siteSetting.key}}
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