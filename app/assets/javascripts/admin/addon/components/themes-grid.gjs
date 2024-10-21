import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import InstallThemeModal from "../components/modal/install-theme";
import ThemesGridCard from "./themes-grid-card";

// NOTE (martin): Much of the JS code in this component is placeholder code. Much
// of the existing theme logic in /admin/customize/themes has old patterns
// and technical debt, so anything copied from there to here is subject
// to change as we improve this incrementally.
export default class ThemesGrid extends Component {
  @service modal;
  @service router;

  externalResources = [
    {
      key: "admin.customize.theme.beginners_guide_title",
      link: "https://meta.discourse.org/t/91966",
    },
    {
      key: "admin.customize.theme.developers_guide_title",
      link: "https://meta.discourse.org/t/93648",
    },
    {
      key: "admin.customize.theme.browse_themes",
      link: "https://meta.discourse.org/c/theme",
    },
  ];

  // Always show the default theme first in the list
  get sortedThemes() {
    return this.args.themes.sort((a, b) => {
      if (a.get("default")) {
        return -1;
      } else if (b.get("default")) {
        return 1;
      }
    });
  }

  // TODO (martin) These install methods may not belong here and they
  // are incomplete or have stubbed or omitted properties. We may want
  // to move this to the new config route or a dedicated component
  // that sits in the route.
  installThemeOptions() {
    return {
      selectedType: "theme",
      userId: null,
      content: null,
      installedThemes: this.args.themes,
      addTheme: this.addTheme,
      updateSelectedType: () => {},
    };
  }

  @action
  addTheme(theme) {
    this.refresh();
    theme.setProperties({ recentlyInstalled: true });
    this.router.transitionTo("adminCustomizeThemes.show", theme.get("id"), {
      queryParams: {
        repoName: null,
        repoUrl: null,
      },
    });
  }

  @action
  installModal() {
    this.modal.show(InstallThemeModal, {
      model: { ...this.installThemeOptions() },
    });
  }

  <template>
    <div class="themes-cards-container">
      <div class="themes-cards-container__main">
        {{#each this.sortedThemes as |theme|}}
          <ThemesGridCard @theme={{theme}} @allThemes={{@themes}} />
        {{/each}}
      </div>
      <div class="themes-cards-container__helper">
        <AdminConfigAreaCard
          class="theme-card"
          @heading="admin.config_areas.look_and_feel.themes.new_theme"
        >
          <:content>
            <p class="theme-card__description">{{i18n
                "admin.customize.theme.themes_intro_new"
              }}</p>
            <div class="external-resources">
              {{#each this.externalResources as |resource|}}
                <a
                  href={{resource.link}}
                  class="external-link"
                  rel="noopener noreferrer"
                  target="_blank"
                >
                  {{i18n resource.key}}
                  {{icon "external-link-alt"}}
                </a>
              {{/each}}
            </div>
            <DButton
              @action={{this.installModal}}
              @icon="upload"
              @label="admin.customize.install"
              class="btn-primary theme-card__install-button"
            />
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
