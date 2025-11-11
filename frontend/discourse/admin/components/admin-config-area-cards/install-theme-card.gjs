import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";

export default class InstallThemeCard extends Component {
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

  get heading() {
    if (this.args.component) {
      return i18n(
        "admin.config_areas.themes_and_components.components.new_component"
      );
    } else {
      return i18n("admin.config_areas.themes_and_components.themes.new_theme");
    }
  }

  get intro() {
    if (this.args.component) {
      return i18n(
        "admin.config_areas.themes_and_components.components.components_intro"
      );
    } else {
      return i18n(
        "admin.config_areas.themes_and_components.themes.themes_intro"
      );
    }
  }

  <template>
    <AdminConfigAreaCard
      class="theme-install-card"
      @translatedHeading={{this.heading}}
    >
      <:content>
        <p>{{this.intro}}</p>
        <div class="theme-install-card__external-links">
          {{#each this.externalResources as |resource|}}
            <a
              href={{resource.link}}
              class="external-link"
              rel="noopener noreferrer"
              target="_blank"
            >
              {{i18n resource.key}}
              {{icon "up-right-from-square"}}
            </a>
          {{/each}}
        </div>
        <DButton
          class="btn-primary theme-install-card__install-button"
          @translatedLabel={{i18n
            "admin.config_areas.themes_and_components.install"
          }}
          @icon="upload"
          @action={{@openModal}}
        />
      </:content>
    </AdminConfigAreaCard>
  </template>
}
