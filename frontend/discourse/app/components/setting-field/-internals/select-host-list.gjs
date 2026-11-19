import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

const TOKEN_SEPARATOR = "|";
const WILDCARD = /[?*]/;

/** Whether a typed host can be stored: no wildcard, and no separator splitting it in two. */
function isStorableHost(host) {
  return !WILDCARD.test(host) && !host.includes(TOKEN_SEPARATOR);
}

/** A host as the picker's record. */
function hostRecord(host) {
  const name = host.trim();
  return { id: name, name };
}

/**
 * Picks a host list setting's hosts, taking typed ones. A host with a wildcard or a separator is
 * never offered for creation, so it can't be stored. A removed host stays listed, unticked, so
 * it can be picked again.
 */
export default class SelectHostList extends Component {
  /**
   * Every host the list has held since the picker rendered, in the order each was first held, so
   * a removed one keeps its row.
   */
  @tracked offered = [];

  get options() {
    return uniqueItemsFromArray([...this.offered, ...this.args.hosts]).map(
      hostRecord
    );
  }

  @action
  onChange(hosts) {
    this.offered = uniqueItemsFromArray([
      ...this.offered,
      ...this.args.hosts,
      ...hosts,
    ]);
    this.args.onChange(hosts);
  }

  <template>
    <DSelect
      @allowCreate={{isStorableHost}}
      @createOption={{hostRecord}}
      @disabled={{@disabled}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @options={{this.options}}
      @texts={{hash
        ariaLabel=@ariaLabel
        placeholder=(i18n "admin.site_settings.host_list.placeholder")
        addMorePlaceholder=(i18n
          "admin.site_settings.host_list.add_more_placeholder"
        )
      }}
      @value={{@hosts}}
    >
      <:empty as |state|>
        {{#if state.query}}
          {{i18n "admin.site_settings.host_list.not_allowed"}}
        {{else}}
          {{i18n "admin.site_settings.host_list.empty"}}
        {{/if}}
      </:empty>
    </DSelect>
  </template>
}
