import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DataSection from "../data-section";

export default class CurrentUserModule extends Component {
  @service currentUser;

  get rawData() {
    if (!this.currentUser) {
      return {};
    }

    const userData = {};
    for (const [key, value] of Object.entries(this.currentUser)) {
      if (value !== null && value !== undefined && !key.startsWith("_")) {
        userData[key] = value;
      }
    }
    return userData;
  }

  get hasContent() {
    return !!this.currentUser;
  }

  <template>
    {{#if this.hasContent}}
      <DataSection
        @sectionKey="current-user"
        @label={{i18n
          (themePrefix "route_inspector.current_user_module.title")
        }}
        @icon="lucide-user"
        @rawData={{this.rawData}}
        @tableKey="current-user"
        @isSectionCollapsed={{@isSectionCollapsed}}
        @onToggleSection={{@onToggleSection}}
        @onDrillInto={{@onDrillInto}}
      />
    {{/if}}
  </template>
}
