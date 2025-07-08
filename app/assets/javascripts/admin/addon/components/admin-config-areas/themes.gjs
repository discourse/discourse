import Component from "@glimmer/component";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import DPageSubheader from "discourse/components/d-page-subheader";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import InstallThemeModal from "admin/components/modal/install-theme";
import ThemesGrid from "admin/components/themes-grid";
import { THEMES } from "admin/models/theme";

export default class AdminConfigAreasThemes extends Component {
  @service modal;
  @service router;
  @service toasts;

  constructor() {
    super(...arguments);

    if (isPresent(this.args.repoName) && isPresent(this.args.repoUrl)) {
      next(() => {
        this.modal.show(InstallThemeModal, {
          model: {
            uploadUrl: this.args.repoUrl,
            uploadName: this.args.repoName,
            selection: "directRepoInstall",
            clearParams: this.clearParams,
            ...this.installThemeOptions(),
          },
        });
      });
    }
  }

  @action
  installModal() {
    this.modal.show(InstallThemeModal, {
      model: { ...this.installThemeOptions() },
    });
  }

  // TODO (martin) These install methods may not belong here and they
  // are incomplete or have stubbed or omitted properties. We may want
  // to move this to the new config route or a dedicated component
  // that sits in the route.
  installThemeOptions() {
    return {
      selectedType: THEMES,
      userId: null,
      content: this.args.themes,
      installedThemes: this.args.themes,
      addTheme: this.addTheme,
      updateSelectedType: () => {},
      showThemesOnly: true,
    };
  }

  @action
  addTheme(theme) {
    this.toasts.success({
      data: {
        message: i18n("admin.customize.theme.install_success", {
          theme: theme.name,
        }),
      },
      duration: "short",
    });
    this.router.transitionTo(
      `adminConfig.customize.${theme.component ? "components" : "themes"}`,
      {
        queryParams: { repoUrl: null, repoName: null },
      }
    );
    this.router.refresh();
  }

  @action
  clearParams() {
    this.router.transitionTo(this.router.currentRouteName, {
      queryParams: { repoUrl: null, repoName: null },
    });
  }

  <template>
    <DPageSubheader
      @titleLabel={{i18n
        "admin.config_areas.themes_and_components.themes.title"
      }}
      @descriptionLabel={{i18n
        "admin.config_areas.themes_and_components.themes.description"
      }}
    >
      <:actions as |actions|>
        <PluginOutlet
          @name="admin-config-area-themes-new-button"
          @outletArgs={{lazyHash actions=actions}}
        >
          <actions.Primary
            @label="admin.config_areas.themes_and_components.themes.install"
            @action={{this.installModal}}
          />
        </PluginOutlet>
      </:actions>
    </DPageSubheader>
    <div class="admin-detail">
      <ThemesGrid @themes={{@themes}} />
    </div>
  </template>
}
