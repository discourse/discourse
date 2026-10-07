/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import SimpleList from "discourse/admin/components/simple-list";
import SimpleListReorderable from "discourse/admin/components/simple-list-reorderable";

@tagName("")
export default class SiteSettingSimpleList extends Component {
  @service siteSettings;

  inputDelimiter = "|";

  @action
  onChange(value) {
    this.set("value", value.join(this.inputDelimiter || "\n"));
  }

  <template>
    <div ...attributes>
      {{! TODO (ui-kit-reorderable-list-cleanup) drop the branch and the
          legacy component once the change ships. }}
      {{#if this.siteSettings.enable_new_reordering_controls}}
        <SimpleListReorderable
          @allowAny={{this.setting.allow_any}}
          @choices={{this.setting.choices}}
          @inputDelimiter={{this.inputDelimiter}}
          @onChange={{this.onChange}}
          @values={{this.value}}
        />
      {{else}}
        <SimpleList
          @allowAny={{this.setting.allow_any}}
          @choices={{this.setting.choices}}
          @inputDelimiter={{this.inputDelimiter}}
          @onChange={{this.onChange}}
          @values={{this.value}}
        />
      {{/if}}
    </div>
  </template>
}
