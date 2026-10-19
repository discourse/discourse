import SelectKitRow from "discourse/select-kit/components/select-kit/select-kit-row";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class SiteTextThemeRow extends SelectKitRow {
  <template>
    <span class="site-text-theme-row">
      <span class="site-text-theme-row__name">{{this.item.name}}</span>
      {{#unless this.isNone}}
        <span class="site-text-theme-row__badge --id">#{{this.item.id}}</span>
        {{#if (eq this.item.enabled false)}}
          <span class="site-text-theme-row__badge --disabled">
            {{i18n "admin.site_text.theme_disabled"}}
          </span>
        {{/if}}
      {{/unless}}
    </span>
  </template>
}
