import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import AdminFilterControls from "discourse/admin/components/admin-filter-controls";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import ThemesGridCard from "./themes-grid-card";

const FILTER_MINIMUM = 8;

export default class ThemesGrid extends Component {
  @cached
  get sortedThemes() {
    return this.args.themes.toSorted((a, b) => {
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

  get showInstallMoreThemesCard() {
    if (this.args.themes.length !== 2) {
      return false;
    }

    return this.args.themes.every((theme) => theme.system);
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
          {{#if this.showInstallMoreThemesCard}}
            <AdminConfigAreaCard class="theme-card --install-more">
              <:content>
                <div class="theme-card__install-more-icon">
                  {{icon "plus"}}
                </div>
                <div class="theme-card__content">
                  <h3 class="theme-card__title">
                    {{i18n "admin.customize.theme.install_more_themes"}}
                  </h3>
                  <p class="theme-card__description">
                    {{i18n
                      "admin.customize.theme.install_more_themes_description"
                    }}
                  </p>
                </div>
                <div class="theme-card__footer">
                  <DButton
                    class="btn-primary theme-card__install-button"
                    @label="admin.config_areas.themes_and_components.themes.install"
                    @icon="upload"
                    @action={{@openInstallModal}}
                  />
                </div>
              </:content>
            </AdminConfigAreaCard>
          {{/if}}
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
