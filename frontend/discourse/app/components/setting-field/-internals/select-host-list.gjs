import { hash } from "@ember/helper";
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

/** The held hosts, which are the only ones the picker lists. */
function hostRecords(hosts) {
  return hosts.map(hostRecord);
}

/**
 * Picks a host list setting's hosts, taking typed ones. A host with a wildcard or a separator is
 * never offered for creation, so it can't be stored.
 */
const SelectHostList = <template>
  <DSelect
    @allowCreate={{isStorableHost}}
    @createOption={{hostRecord}}
    @disabled={{@disabled}}
    @multiple={{true}}
    @onChange={{@onChange}}
    @options={{hostRecords @hosts}}
    @texts={{hash
      ariaLabel=@ariaLabel
      placeholder=(i18n "admin.site_settings.host_list.placeholder")
      addMorePlaceholder=(i18n
        "admin.site_settings.host_list.add_more_placeholder"
      )
      noResults=(i18n "admin.site_settings.host_list.not_allowed")
    }}
    @value={{@hosts}}
  />
</template>;

export default SelectHostList;
