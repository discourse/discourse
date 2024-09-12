import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import InstallThemeModal from "../components/modal/install-theme";
import ThemesGridCard from "./themes-grid-card";

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

  get sortedThemes() {
    // always show currently set default theme first
    return this.args.themes.sort((a, b) => {
      if (a.default) {
        return -1;
      } else if (b.default) {
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
      {{#each this.sortedThemes as |theme|}}
        <ThemesGridCard @theme={{theme}} @allThemes={{this.args.themes}}/>
      {{/each}}

      <div class="admin-config-area-card theme-card">
        <div class="theme-card-content">
          <h2 class="theme-card-title">{{i18n
              "admin.config_areas.themes.new_theme"
            }}</h2>
          <p class="theme-card-description">{{i18n
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
        </div>
        <DButton
          @action={{this.installModal}}
          @icon="upload"
          @label="admin.customize.install"
          class="btn-primary theme-card-button"
        />
      </div>
    </div>
  </template>
}
