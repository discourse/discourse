import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { sortOrders } from "../../../../../lib/select-fixtures.js";

const SITE_DEFAULT = "latest";

/**
 * What a plugin registers at boot, through the `select-customizations` value transformer. The
 * styleguide's own initializer passes it the registry.
 *
 * @param {object} selects - the customization registry.
 */
export function markSiteDefault(selects) {
  selects.forIdentifier("sg-held-mark", (spec) =>
    spec.content((options) =>
      options.map((option) =>
        option.record.id === SITE_DEFAULT
          ? option.with({
              icon: "star",
              description: i18n(
                "styleguide.sections.select.content.held_mark_site_default"
              ),
            })
          : option
      )
    )
  );
}

export default class HeldMarkSelectExample extends Component {
  @tracked value = SITE_DEFAULT;

  items = sortOrders();

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-held-mark"
      @labelField="name"
      @onChange={{this.onChange}}
      @options={{this.items}}
      @value={{this.value}}
      @variant="button"
    />
  </template>
}
