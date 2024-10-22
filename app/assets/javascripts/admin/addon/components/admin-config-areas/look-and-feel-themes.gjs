import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminPageSubheader from "admin/components/admin-page-subheader";
import InstallThemeModal from "admin/components/modal/install-theme";
import ThemesGrid from "admin/components/themes-grid";

export default class AdminConfigAreasLookAndFeelThemes extends Component {
  @service modal;

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

  <template>
    <AdminPageSubheader
      @titleLabel="admin.config_areas.look_and_feel.themes.title"
      @descriptionLabel="admin.customize.theme.themes_intro_new"
      @learnMoreUrl="https://meta.discourse.org/t/93648"
    >
      <:actions as |actions|>
        <actions.Primary
          @action={{this.installModal}}
          @label="admin.customize.install"
          @icon="upload"
          class="admin-look-and-feel__install-theme"
        />
      </:actions>
    </AdminPageSubheader>

    <div class="admin-detail">
      <ThemesGrid @themes={{@themes}} />
    </div>
  </template>
}
