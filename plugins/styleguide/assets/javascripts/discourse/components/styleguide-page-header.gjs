import Component from "@glimmer/component";
import { service } from "@ember/service";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";
import ToggleColorMode from "discourse/plugins/styleguide/discourse/components/toggle-color-mode";
import sectionTitle from "discourse/plugins/styleguide/discourse/helpers/section-title";

export default class StyleguidePageHeader extends Component {
  @service router;

  get title() {
    const { currentRoute } = this.router;

    if (currentRoute?.name === "styleguide.show") {
      return sectionTitle(currentRoute.params.section);
    }

    return i18n("styleguide.title");
  }

  <template>
    <DPageHeader
      class="styleguide-page-header"
      @titleLabel={{this.title}}
      @hideTabs={{true}}
    >
      <:actions as |actions|>
        <actions.Wrapped>
          <ToggleColorMode />
        </actions.Wrapped>
      </:actions>
    </DPageHeader>
  </template>
}
