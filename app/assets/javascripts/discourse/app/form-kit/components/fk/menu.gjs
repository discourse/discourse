import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "float-kit/components/d-menu";

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
    <DMenu @identifier={{@field.name}} @icon="gear" @triggerClass="btn-flat">
      <:content>
        <DropdownMenu as |dropdown|>
          <dropdown.item>
            <DButton
              @label="reset_setting"
              class="btn-transparent"
              @action={{this.resetSetting}}
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              @label="copy_setting"
              class="btn-transparent"
              @action={{this.copyLinkToSetting}}
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              @label="setting_history"
              class="btn-transparent"
              @action={{this.showSettingHistory}}
            />
          </dropdown.item>
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
