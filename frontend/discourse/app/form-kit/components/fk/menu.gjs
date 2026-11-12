import Component from "@glimmer/component";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";

export default class FKMenu extends Component {
  @action
  copyLinkToSetting() {
    // rectonstruct this url from setting name
    // /admin/site_settings/category/required?filter=default_locale
    // show a toast: "Link copied to clipboard"
    // close the menu
  }

  @action
  resetSetting() {
    // same than current behavior
    // show a toast: "Setting reset to default"
    // close the menu
  }

  @action
  showSettingHistory() {
    // link to /admin/logs/staff_action_logs?filters=%7B"subject"%3A"default_locale"%2C"action_name"%3A"change_site_setting"%7D
  }

  <template>
    <DMenu @icon="gear" @identifier={{@field.name}} @triggerClass="btn-flat">
      <:content>
        <DDropdownMenu as |dropdown|>
          <dropdown.item>
            <DButton
              class="btn-transparent"
              @action={{this.resetSetting}}
              @label="reset_setting"
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              class="btn-transparent"
              @action={{this.copyLinkToSetting}}
              @label="copy_setting"
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              class="btn-transparent"
              @action={{this.showSettingHistory}}
              @label="setting_history"
            />
          </dropdown.item>
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
