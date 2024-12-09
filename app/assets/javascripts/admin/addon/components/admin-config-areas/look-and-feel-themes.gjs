import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";
import InstallThemeModal from "admin/components/modal/install-theme";
import ThemesGrid from "admin/components/themes-grid";

export default class AdminConfigAreasLookAndFeelThemes extends Component {
  @service modal;
  @service router;
  @service toasts;

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
      content: [],
      installedThemes: this.args.themes,
      addTheme: this.addTheme,
      updateSelectedType: () => {},
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
      duration: 2000,
    });
    this.router.refresh();
  }

  <template>
    <DPageSubheader
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
    </DPageSubheader>

    <div class="admin-detail">
      <ThemesGrid @themes={{@themes}} />
    </div>
  </template>
}
