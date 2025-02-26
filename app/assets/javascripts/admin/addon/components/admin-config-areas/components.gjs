import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import InstallThemeModal from "admin/components/modal/install-theme";
import ThemesGrid from "admin/components/themes-grid";
import { COMPONENTS } from "admin/models/theme";

export default class AdminConfigAreasComponents extends Component {
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
      selectedType: COMPONENTS,
      userId: null,
      content: [],
      installedThemes: this.args.components,
      addTheme: this.addTheme,
      updateSelectedType: () => {},
      showComponentsOnly: true,
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
    <div class="admin-detail">
      <ThemesGrid @themes={{@components}} />
    </div>
  </template>
}
