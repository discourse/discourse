import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import routeAction from "discourse/helpers/route-action";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import ThemesGridCard from "./themes-grid-card";

export default class ThemesGrid extends Component {
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

  constructor() {
    super(...arguments);
  }

  get sortedThemes() { // always show currently set default theme first
    return this.args.themes.sort((a,b) => {
      if (a.default) {
        return -1;
      } else if (b.default) {
        return 1;
      }
    });
  }

  <template>
    <div class="themes-cards-container">
      {{#each this.sortedThemes as |theme|}}
        <ThemesGridCard @theme={{theme}} />
      {{/each}}
      <div class="theme-card">
        <div class="theme-card-content">
          <h2 class="theme-card-title">New Theme</h2>
          <p class="theme-card-description">{{i18n "admin.customize.theme.themes_intro_new"}}</p>
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
          @action={{routeAction "installModal"}}
          @icon="upload"
          @label="admin.customize.install"
          class="btn-primary theme-card-button"
        />
      </div>
    </div>
  </template>
}