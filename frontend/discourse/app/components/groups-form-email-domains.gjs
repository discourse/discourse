import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

const TOKEN_SEPARATOR = "|";

/** A domain as the picker's record. */
function domainRecord(domain) {
  const name = domain.trim();
  return { id: name, name };
}

/** Whether a typed domain can be stored: a separator would split it in two. */
function isStorableDomain(domain) {
  return !domain.includes(TOKEN_SEPARATOR);
}

/**
 * Picks the email domains a group adds members by, taking typed ones. The server normalizes each
 * domain and refuses the ones it can't use, so only a separator is refused here. A removed domain
 * stays listed, unticked, so it can be picked again.
 */
export default class GroupsFormEmailDomains extends Component {
  /**
   * Every domain the list has held since the picker rendered, in the order each was first held,
   * so a removed one keeps its row.
   */
  @tracked offered = [];

  get options() {
    return uniqueItemsFromArray([...this.offered, ...this.args.domains]).map(
      domainRecord
    );
  }

  @action
  onChange(domains) {
    this.offered = uniqueItemsFromArray([
      ...this.offered,
      ...this.args.domains,
      ...domains,
    ]);
    this.args.onChange(domains);
  }

  <template>
    <DSelect
      ...attributes
      @allowCreate={{isStorableDomain}}
      @createOption={{domainRecord}}
      @id={{@id}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @options={{this.options}}
      @texts={{hash
        placeholder=(i18n
          "admin.groups.manage.membership.email_domains.placeholder"
        )
        addMorePlaceholder=(i18n
          "admin.groups.manage.membership.email_domains.add_more_placeholder"
        )
      }}
      @value={{@domains}}
    >
      <:empty as |state|>
        {{#if state.query}}
          {{i18n "admin.groups.manage.membership.email_domains.not_allowed"}}
        {{else}}
          {{i18n "admin.groups.manage.membership.email_domains.empty"}}
        {{/if}}
      </:empty>
    </DSelect>
  </template>
}
