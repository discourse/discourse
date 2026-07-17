import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import withEventValue from "discourse/helpers/with-event-value";
import discourseLater from "discourse/lib/later";
import DButton from "discourse/ui-kit/d-button";
import DIconGridPicker from "discourse/ui-kit/d-icon-grid-picker";
import DSelect from "discourse/ui-kit/d-select";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SectionFormLink extends Component {
  @service site;

  @tracked dragCssClass;
  dragCount = 0;

  isAboveElement(event) {
    event.preventDefault();
    const target = event.currentTarget;
    const domRect = target.getBoundingClientRect();
    return event.offsetY < domRect.height / 2;
  }

  @action
  dragHasStarted(event) {
    event.dataTransfer.effectAllowed = "move";
    this.args.setDraggedLinkCallback(this.args.link);
    this.dragCssClass = "dragging";
  }

  @action
  dragOver(event) {
    event.preventDefault();
    if (this.dragCssClass !== "dragging") {
      if (this.isAboveElement(event)) {
        this.dragCssClass = "drag-above";
      } else {
        this.dragCssClass = "drag-below";
      }
    }
  }

  @action
  dragEnter() {
    this.dragCount++;
  }

  @action
  dragLeave() {
    this.dragCount--;
    if (
      this.dragCount === 0 &&
      (this.dragCssClass === "drag-above" || this.dragCssClass === "drag-below")
    ) {
      discourseLater(() => {
        this.dragCssClass = null;
      }, 10);
    }
  }

  @action
  dropItem(event) {
    event.stopPropagation();
    this.dragCount = 0;
    this.args.reorderCallback(this.args.link, this.isAboveElement(event));
    this.dragCssClass = null;
  }

  @action
  dragEnd() {
    this.dragCount = 0;
    this.dragCssClass = null;
  }

  get activeLocalizations() {
    return this.args.link.localizations.filter(
      (localization) => !localization._destroy
    );
  }

  <template>
    <div class="sidebar-section-form-link-wrapper" role="rowgroup">
      <div
        {{on "dragover" this.dragOver}}
        {{on "dragenter" this.dragEnter}}
        {{on "dragleave" this.dragLeave}}
        {{on "dragend" this.dragEnd}}
        {{on "drop" this.dropItem}}
        role="row"
        data-row-id={{@link.objectId}}
        class={{dConcatClass
          "sidebar-section-form-link"
          "row-wrapper"
          this.dragCssClass
        }}
      >
        {{#if this.site.desktopView}}
          <div
            {{on "dragstart" this.dragHasStarted}}
            class="draggable"
            data-link-name={{@link.name}}
            draggable="true"
          >
            {{dIcon "grip-lines"}}
          </div>
        {{/if}}

        <div class="input-group" role="cell">
          <DIconGridPicker
            @value={{@link.icon}}
            @onChange={{fn (mut @link.icon)}}
            @showCaret={{true}}
            @btnClass={{dConcatClass "btn-default" @link.iconCssClass}}
            aria-label={{i18n "sidebar.sections.custom.links.icon.label"}}
          />

          {{#if @link.invalidIconMessage}}
            <div class="icon warning" role="alert" aria-live="assertive">
              {{@link.invalidIconMessage}}
            </div>
          {{/if}}
        </div>

        <div class="input-group" role="cell">
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <Input
            {{on "input" (withEventValue (fn (mut @link.name)))}}
            @type="text"
            @value={{@link.name}}
            name="link-name"
            aria-label={{i18n "sidebar.sections.custom.links.name.label"}}
            class={{@link.nameCssClass}}
            data-1p-ignore
          />

          {{#if @link.invalidNameMessage}}
            <div role="alert" aria-live="assertive" class="name warning">
              {{@link.invalidNameMessage}}
            </div>
          {{/if}}
        </div>

        <div class="input-group" role="cell">
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <Input
            {{on "input" (withEventValue (fn (mut @link.value)))}}
            @type="text"
            @value={{@link.value}}
            name="link-url"
            aria-label={{i18n "sidebar.sections.custom.links.value.label"}}
            class={{@link.valueCssClass}}
          />

          {{#if @link.invalidValueMessage}}
            <div role="alert" aria-live="assertive" class="value warning">
              {{@link.invalidValueMessage}}
            </div>
          {{/if}}
        </div>

        <DButton
          @icon="trash-can"
          @action={{fn @deleteLink @link}}
          @title="sidebar.sections.custom.links.delete"
          role="cell"
          class="btn-flat delete-link"
        />
      </div>

      {{#if @showLocalizations}}
        <div class="sidebar-section-form-link__localizations">
          {{#each this.activeLocalizations as |localization|}}
            <div class="sidebar-section-form__localization-row">
              <DSelect
                @value={{localization.locale}}
                @onChange={{fn (mut localization.locale)}}
                @includeNone={{false}}
                class="sidebar-section-form__localization-locale"
                aria-label={{i18n
                  "sidebar.sections.custom.localizations.locale"
                }}
                as |select|
              >
                {{#each @localeOptions as |locale|}}
                  <select.Option
                    @value={{locale.value}}
                  >{{locale.name}}</select.Option>
                {{/each}}
              </DSelect>

              <Input
                @type="text"
                @value={{localization.name}}
                class="sidebar-section-form__localization-value"
                placeholder={{i18n
                  "sidebar.sections.custom.localizations.link_label"
                }}
                aria-label={{i18n
                  "sidebar.sections.custom.localizations.link_label"
                }}
                {{on "input" (withEventValue (fn (mut localization.name)))}}
              />

              <DButton
                @icon="trash-can"
                @action={{fn @deleteLocalization @link localization}}
                @title="sidebar.sections.custom.localizations.remove"
                class="btn-flat delete-link remove-localization"
              />
            </div>

            {{#if localization.invalidNameMessage}}
              <div role="alert" aria-live="assertive" class="name warning">
                {{localization.invalidNameMessage}}
              </div>
            {{/if}}
          {{/each}}

          <DButton
            @action={{fn @addLocalization @link}}
            @title="sidebar.sections.custom.localizations.add_link"
            @icon="plus"
            @label="sidebar.sections.custom.localizations.add_link"
            class="btn-flat btn-text add-link-localization"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
