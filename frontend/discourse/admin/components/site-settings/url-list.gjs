/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import ValueList from "discourse/admin/components/value-list";
import ValueListReorderable from "discourse/admin/components/value-list-reorderable";

@tagName("")
export default class UrlList extends Component {
  @service siteSettings;

  <template>
    <div ...attributes>
      {{! TODO (ui-kit-reorderable-list-cleanup) drop the branch and the
          legacy component once the change ships. }}
      {{#if this.siteSettings.enable_new_reordering_controls}}
        <ValueListReorderable
          @disabled={{@disabled}}
          @values={{this.value}}
          @addKey="admin.site_settings.add_url"
        />
      {{else}}
        <ValueList
          @disabled={{@disabled}}
          @values={{this.value}}
          @addKey="admin.site_settings.add_url"
        />
      {{/if}}
    </div>
  </template>
}
