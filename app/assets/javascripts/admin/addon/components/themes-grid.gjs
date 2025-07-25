import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminFilterControls from "admin/components/admin-filter-controls";
import ThemesGridCard from "./themes-grid-card";

// NOTE (martin): Much of the JS code in this component is placeholder code. Much
// of the existing theme logic in /admin/customize/themes has old patterns
// and technical debt, so anything copied from there to here is subject
// to change as we improve this incrementally.

const FILTER_MINIMUM = 8;

export default class ThemesGrid extends Component {
  @service modal;
  @service router;

  sortedThemes;

  constructor() {
    super(...arguments);

    // Show default theme at the top of the list on page load,
    // but don't move it around dynamically if the admin changes the default.
    //
    // TODO (martin) Figure out how to make it so we can sort default to the
    // top but also allow the list of themes to change if an additional theme is
    // installed. Basically don't want .get("default") to affect the sort after
    // the first time, but if the whole array changes this needs to be recalculated.
    this.sortedThemes = this.args.themes.sort((a, b) => {
      if (a.get("default")) {
        return -1;
      } else if (b.get("default")) {
        return 1;
      }
      if (a.id < 0) {
        return a.id;
      }
      if (b.id < 0) {
        return -b.id;
      }
    });
  }

  get searchableProps() {
    return ["name", "description"];
  }

  get inputPlaceholder() {
    return i18n("admin.customize.theme.search_placeholder");
  }

  get dropdownOptions() {
    return [
      {
        value: "all",
        label: i18n("admin.customize.theme.filter_all"),
        filterFn: () => true,
      },
      {
        value: "user_selectable",
        label: i18n("admin.customize.theme.filter_user_selectable"),
        filterFn: (theme) => theme.user_selectable,
      },
    ];
  }

  <template>
    <AdminFilterControls
      @array={{this.sortedThemes}}
      @minItemsForFilter={{FILTER_MINIMUM}}
      @searchableProps={{this.searchableProps}}
      @dropdownOptions={{this.dropdownOptions}}
      @inputPlaceholder={{this.inputPlaceholder}}
      @noResultsMessage={{i18n "admin.customize.theme.no_themes_found"}}
      as |themes|
    >
      <div class="themes-cards-container">
        {{#each themes as |theme|}}
          <ThemesGridCard @theme={{theme}} @allThemes={{@themes}} />
        {{/each}}
        <PluginOutlet
          @name="admin-themes-grid-additional-cards"
          @outletArgs={{lazyHash
            AdminConfigAreaCardComponent=AdminConfigAreaCard
          }}
        />
      </div>
    </AdminFilterControls>
  </template>
}
