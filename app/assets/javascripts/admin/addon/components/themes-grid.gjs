import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminFilterControls from "admin/components/admin-filter-controls";
import ThemesGridCard from "./themes-grid-card";

const FILTER_MINIMUM = 8;

export default class ThemesGrid extends Component {
  @cached
  get sortedThemes() {
    return this.args.themes.sort((a, b) => {
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
    >
      <:content as |themes|>
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
      </:content>
    </AdminFilterControls>
  </template>
}
