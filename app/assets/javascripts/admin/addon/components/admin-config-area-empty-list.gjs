import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreaEmptyList extends Component {
  get emptyLabel() {
    if (this.args.emptyLabelTranslated) {
      return this.args.emptyLabelTranslated;
    }

    return i18n(this.args.emptyLabel);
  }

  <template>
    <div class="admin-config-area-empty-list">
      {{htmlSafe this.emptyLabel}}

      {{#if @ctaLabel}}
        <DButton
          @label={{@ctaLabel}}
          class={{concatClass
            "btn-default btn-small admin-config-area-empty-list__cta-button"
            @ctaClass
          }}
          @action={{@ctaAction}}
          @route={{@ctaRoute}}
        />
      {{/if}}
    </div>
  </template>
}
