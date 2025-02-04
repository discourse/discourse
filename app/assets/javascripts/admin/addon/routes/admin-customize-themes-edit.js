import { action } from "@ember/object";
import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class AdminCustomizeThemesEditRoute extends Route {
  @service dialog;
  @service router;

  model(params) {
    const all = this.modelFor("adminCustomizeThemes");
    const model = all.findBy("id", parseInt(params.theme_id, 10));
    if (model) {
      return {
        model,
        target: params.target,
        field_name: params.field_name,
      };
    } else {
      this.router.replaceWith("adminCustomizeThemes.index");
    }
  }

  serialize(wrapper) {
    return {
      model: wrapper.model,
      target: wrapper.target || "common",
      field_name: wrapper.field_name || "scss",
      theme_id: wrapper.model.get("id"),
    };
  }

  setupController(controller, wrapper) {
    const fields = wrapper.model
      .get("fields")
      [wrapper.target].map((f) => f.name);
    if (wrapper.model.remote_theme && wrapper.model.remote_theme.is_git) {
      this.router.transitionTo("adminCustomizeThemes.index");
      return;
    }
    if (!fields.includes(wrapper.field_name)) {
      this.router.transitionTo(
        "adminCustomizeThemes.edit",
        wrapper.model.id,
        wrapper.target,
        fields[0]
      );
      return;
    }
    controller.set("model", wrapper.model);
    controller.setTargetName(wrapper.target || "common");
    controller.set("fieldName", wrapper.field_name || "scss");
    this.controllerFor("adminCustomizeThemes").set("editingTheme", true);
    this.set("shouldAlertUnsavedChanges", true);
  }

  @action
  willTransition(transition) {
    if (
      this.get("controller.model.changed") &&
      this.shouldAlertUnsavedChanges &&
      transition.intent.name !== this.routeName
    ) {
      transition.abort();

      this.dialog.confirm({
        message: i18n("admin.customize.theme.unsaved_changes_alert"),
        confirmButtonLabel: "admin.customize.theme.discard",
        cancelButtonLabel: "admin.customize.theme.stay",
        didConfirm: () => {
          this.set("shouldAlertUnsavedChanges", false);
          transition.retry();
        },
      });
    }
  }
}
