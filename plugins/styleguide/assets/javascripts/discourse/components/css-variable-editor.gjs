import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { loadColorSchemeStylesheet } from "discourse/lib/color-scheme-picker";
import { currentThemeId } from "discourse/lib/theme-selector";
import { not } from "discourse/truth-helpers";
import { getCssVariableCategories } from "../lib/css-variables-registry";
import CssEditorCategory from "./css-editor-category";

const DARK = "dark";
const LIGHT = "light";

function colorSchemeOverride(type) {
  const lightScheme = document.querySelector("link.light-scheme");
  const darkScheme =
    document.querySelector("link.dark-scheme") ||
    document.querySelector("link#cs-preview-dark");

  if (!lightScheme && !darkScheme) {
    return;
  }

  switch (type) {
    case DARK:
      lightScheme.origMedia = lightScheme.media;
      lightScheme.media = "none";
      darkScheme.origMedia = darkScheme.media;
      darkScheme.media = "all";
      break;
    case LIGHT:
      lightScheme.origMedia = lightScheme.media;
      lightScheme.media = "all";
      darkScheme.origMedia = darkScheme.media;
      darkScheme.media = "none";
      break;
    default:
      if (lightScheme.origMedia) {
        lightScheme.media = lightScheme.origMedia;
        lightScheme.removeAttribute("origMedia");
      }
      if (darkScheme.origMedia) {
        darkScheme.media = darkScheme.origMedia;
        darkScheme.removeAttribute("origMedia");
      }
      break;
  }
}

export default class CssVariableEditor extends Component {
  @service cssEditorState;
  @service site;

  @tracked searchQuery = "";
  @tracked colorSchemeOverride = this.defaultColorScheme;
  @tracked canToggleColorMode = true;

  constructor() {
    super(...arguments);

    if (!document.querySelector("link.dark-scheme")) {
      if (this.site.default_dark_color_scheme?.id > 0) {
        loadColorSchemeStylesheet(
          this.site.default_dark_color_scheme.id,
          currentThemeId(),
          true
        );
      } else {
        this.canToggleColorMode = false;
      }
    }
  }

  get defaultColorScheme() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches
      ? DARK
      : LIGHT;
  }

  get categories() {
    return getCssVariableCategories();
  }

  get categoryEntries() {
    return [...this.categories.entries()].map(([name, variables]) => ({
      name,
      variables,
    }));
  }

  @action
  togglePanel() {
    this.cssEditorState.toggle();
  }

  @action
  toggleColorMode() {
    this.colorSchemeOverride = this.colorSchemeOverride === DARK ? LIGHT : DARK;
    colorSchemeOverride(this.colorSchemeOverride);
  }

  @action
  onSearchInput(event) {
    this.searchQuery = event.target.value;
  }

  @action
  resetAll() {
    this.cssEditorState.resetAll();
  }

  @action
  async exportCSS() {
    const css = this.cssEditorState.exportCSS;
    if (css) {
      await navigator.clipboard.writeText(css);
    }
  }

  <template>
    <button
      type="button"
      class="css-editor-toggle btn-flat btn-icon no-text"
      title="CSS Variable Editor"
      {{on "click" this.togglePanel}}
    >
      {{icon "paintbrush"}}
    </button>

    {{#if this.cssEditorState.isOpen}}
      <div class="css-variable-editor">
        <div class="css-variable-editor__header">
          <h3 class="css-variable-editor__title">CSS Variable Editor</h3>
          <button
            type="button"
            class="css-variable-editor__close btn-flat btn-icon no-text"
            {{on "click" this.togglePanel}}
          >
            {{icon "xmark"}}
          </button>
        </div>

        <div class="css-variable-editor__toolbar">
          {{#if this.canToggleColorMode}}
            <DButton
              @action={{this.toggleColorMode}}
              @icon="circle-half-stroke"
              class="btn-default btn-small css-variable-editor__color-mode-toggle"
            >Toggle Light/Dark Mode</DButton>
          {{/if}}
          <input
            type="text"
            value={{this.searchQuery}}
            placeholder="Search variables..."
            class="css-variable-editor__search"
            {{on "input" this.onSearchInput}}
          />
          <div class="css-variable-editor__actions">
            <DButton
              @label="styleguide.css_editor.reset_all"
              @action={{this.resetAll}}
              @disabled={{not this.cssEditorState.hasOverrides}}
              class="btn-default btn-small"
            />
            <DButton
              @label="styleguide.css_editor.export"
              @action={{this.exportCSS}}
              @disabled={{not this.cssEditorState.hasOverrides}}
              class="btn-primary btn-small"
            />
          </div>
        </div>

        <div class="css-variable-editor__body">
          {{#each this.categoryEntries as |entry|}}
            <CssEditorCategory
              @categoryName={{entry.name}}
              @variables={{entry.variables}}
              @searchQuery={{this.searchQuery}}
            />
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>
}
