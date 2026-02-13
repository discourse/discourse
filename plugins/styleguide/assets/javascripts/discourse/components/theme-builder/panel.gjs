import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import draggableNode from "discourse/plugins/styleguide/discourse/modifiers/draggable-node";
import ColorDefinitionsSection from "./color-definitions-section";
import ColorSection from "./color-section";
import CssSection from "./css-section";
import SaveThemeModal from "./save-theme-modal";

export default class ThemeBuilderPanel extends Component {
  @service themeBuilderState;
  @service modal;
  @service dialog;

  @action
  onPanelMove(top, left) {
    this.themeBuilderState.panelTop = top;
    this.themeBuilderState.panelLeft = left;
  }

  @action
  switchTab(tabId) {
    this.themeBuilderState.setActiveTab(tabId);
  }

  @action
  handleClose() {
    this.themeBuilderState.toggle();
  }

  @action
  openSaveModal() {
    this.modal.show(SaveThemeModal);
  }

  @action
  handleUpdate() {
    this.themeBuilderState.update();
  }

  @action
  handleReset() {
    this.dialog.yesNoConfirm({
      message: i18n("styleguide.theme_builder.reset_confirm"),
      didConfirm: () => this.themeBuilderState.reset(),
    });
  }

  get activeTab() {
    return this.themeBuilderState.activeTab;
  }

  get isSaveDisabled() {
    return (
      this.themeBuilderState.isCompiling || !this.themeBuilderState.hasDraft
    );
  }

  <template>
    {{#if this.themeBuilderState.isOpen}}
      <div
        class="theme-builder-panel"
        {{draggableNode ".theme-builder-panel__header" onMove=this.onPanelMove}}
      >
        <div class="theme-builder-panel__header">
          <h3>{{i18n "styleguide.theme_builder.title"}}</h3>
          {{#if this.themeBuilderState.isCompiling}}
            <span class="theme-builder-panel__compiling">
              {{i18n "styleguide.theme_builder.compiling"}}
            </span>
          {{/if}}
          <DButton
            @action={{this.handleClose}}
            @icon="xmark"
            class="btn-flat btn-icon no-text theme-builder-panel__close"
          />
        </div>

        {{#if this.themeBuilderState.themeName}}
          <div class="theme-builder-panel__theme-info">
            <a
              href={{this.themeBuilderState.themeAdminUrl}}
              target="_blank"
              rel="noopener noreferrer"
              class="theme-builder-panel__theme-link"
            >{{this.themeBuilderState.themeName}}</a>
          </div>
        {{/if}}

        <div class="theme-builder-panel__tabs">
          {{#each this.themeBuilderState.tabs as |tab|}}
            <button
              type="button"
              class="btn btn-flat theme-builder-panel__tab
                {{if (eq this.activeTab tab.id) 'active'}}"
              {{on "click" (fn this.switchTab tab.id)}}
            >
              {{i18n tab.label}}
            </button>
          {{/each}}
        </div>

        <div class="theme-builder-panel__body">
          {{#if (eq this.activeTab "light-colors")}}
            <ColorSection @mode="light" />
          {{else if (eq this.activeTab "dark-colors")}}
            <ColorSection @mode="dark" />
          {{else if (eq this.activeTab "css")}}
            <CssSection />
          {{else if (eq this.activeTab "color-definitions")}}
            <ColorDefinitionsSection />
          {{/if}}
        </div>

        <div class="theme-builder-panel__footer">
          {{#if this.themeBuilderState.themeName}}
            <DButton
              @action={{this.handleUpdate}}
              @label="styleguide.theme_builder.update"
              class="btn-primary"
              @disabled={{this.themeBuilderState.isCompiling}}
            />
          {{else}}
            <DButton
              @action={{this.openSaveModal}}
              @label="styleguide.theme_builder.save_as_theme"
              class="btn-primary"
              @disabled={{this.isSaveDisabled}}
            />
          {{/if}}
          <DButton
            @action={{this.handleReset}}
            @label="styleguide.theme_builder.reset"
            class="btn-danger"
          />
        </div>
      </div>
    {{/if}}
  </template>
}
