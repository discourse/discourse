import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { i18n } from "discourse-i18n";
import InstallComponentModal from "admin/components/modal/install-theme";
import { COMPONENTS } from "admin/models/theme";

export default class AdminConfigAreasComponents extends Component {
  @service modal;
  @service router;
  @service toasts;

  @action
  installModal() {
    this.modal.show(InstallComponentModal, {
      model: { ...this.installOptions() },
    });
  }

  // TODO (martin) These install methods may not belong here and they
  // are incomplete or have stubbed or omitted properties. We may want
  // to move this to the new config route or a dedicated component
  // that sits in the route.
  installOptions() {
    return {
      selectedType: COMPONENTS,
      userId: null,
      content: [],
      installedThemes: this.args.components,
      addTheme: this.addComponent,
      updateSelectedType: () => {},
      showComponentsOnly: true,
    };
  }

  @action
  addComponent(component) {
    this.toasts.success({
      data: {
        message: i18n("admin.customize.theme.install_success", {
          theme: component.name,
        }),
      },
      duration: 2000,
    });
    this.router.refresh();
  }

  <template>
    <div class="container">
      <table class="d-admin-table">
        <thead>
          <th>{{i18n
              "admin.config_areas.themes_and_components.components.name"
            }}</th>
          <th>{{i18n
              "admin.config_areas.themes_and_components.components.used_on"
            }}</th>
          <th>{{i18n
              "admin.config_areas.themes_and_components.components.enabled"
            }}</th>
        </thead>
        <tbody>
          {{#each @model.components as |comp|}}
            <tr class="d-admin-row__content">
              <td class="d-admin-row__overview">
                <div class="d-admin-row__overview-name">{{comp.name}}</div>
                {{#if comp.remote_theme.authors}}
                  <div class="d-admin-row__overview-about">{{i18n
                      "admin.config_areas.themes_and_components.components.by_author"
                      (hash name=comp.remote_theme.authors)
                    }}</div>
                {{/if}}
                {{#if comp.description}}
                  <p>
                    {{comp.description}}
                    {{#if comp.remote_theme.about_url}}
                      <a href={{comp.remote_theme.about_url}}>{{i18n
                          "admin.config_areas.themes_and_components.components.learn_more"
                        }}</a>
                    {{/if}}
                  </p>
                {{/if}}
              </td>
              <td class="d-admin-row__detail">
              </td>
              <td class="d-admin-row__controls">
                <div class="d-admin-row__controls-options">
                  <div class="d-admin-row__mobile-label">
                    {{i18n "admin.config_areas.flags.enabled"}}
                  </div>
                  <DToggleSwitch
                    @state={{this.enabled}}
                    class="admin-flag-item__toggle {{@flag.name_key}}"
                    {{on "click" (fn this.toggleFlagEnabled @flag)}}
                  />
                </div>
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </div>
  </template>
}
