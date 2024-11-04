import Component from "@glimmer/component";
import { service } from "@ember/service";
import ThemesGridCard from "./themes-grid-card";

// NOTE (martin): Much of the JS code in this component is placeholder code. Much
// of the existing theme logic in /admin/customize/themes has old patterns
// and technical debt, so anything copied from there to here is subject
// to change as we improve this incrementally.
export default class ThemesGrid extends Component {
  @service modal;
  @service router;

  sortedThemes;

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
    });
  }

  <template>
    <div class="themes-cards-container">
      {{#each @themes as |theme|}}
        <ThemesGridCard @theme={{theme}} @allThemes={{@themes}} />
      {{/each}}
    </div>
  </template>
}
