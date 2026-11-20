import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ComboBox from "discourse/select-kit/components/combo-box";
import MultiSelect from "discourse/select-kit/components/multi-select";
import { i18n } from "discourse-i18n";

export default class AllowedUserLocales extends Component {
  @service siteSettings;

  get modes() {
    return ["all", "selected", "none"].map((value) => ({
      value,
      name: i18n(`admin.site_settings.allowed_user_locales.${value}`),
    }));
  }

  get mode() {
    const value = this.args.value;
    return value === "all" || value === "none" ? value : "selected";
  }

  get selectingLanguages() {
    return this.mode === "selected";
  }

  get selectedLocales() {
    const value = this.args.value;
    return value === "all" || value === "none" || !value
      ? []
      : value.split("|");
  }

  @action
  changeMode(mode) {
    if (mode === "selected") {
      this.changeLocales(this.selectedLocales);
    } else {
      this.args.changeValueCallback(mode);
      this.args.setValidationMessage?.(null);
    }
  }

  @action
  changeLocales(locales) {
    this.args.changeValueCallback(locales.join("|"));
    this.args.setValidationMessage?.(
      locales.length
        ? null
        : i18n("admin.site_settings.allowed_user_locales.select_languages")
    );
  }

  <template>
    <div ...attributes>
      <ComboBox
        aria-label={{i18n "admin.site_settings.allowed_user_locales.mode"}}
        @content={{this.modes}}
        @onChange={{this.changeMode}}
        @options={{hash disabled=@disabled}}
        @value={{this.mode}}
        @valueProperty="value"
      />
      {{#if this.selectingLanguages}}
        <MultiSelect
          aria-label={{i18n
            "admin.site_settings.allowed_user_locales.select_languages"
          }}
          @content={{this.siteSettings.available_locales}}
          @onChange={{this.changeLocales}}
          @options={{hash disabled=@disabled}}
          @value={{this.selectedLocales}}
          @valueProperty="value"
        />
      {{/if}}
    </div>
  </template>
}
