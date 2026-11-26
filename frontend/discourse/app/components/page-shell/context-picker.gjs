import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ContextPicker extends Component {
  @service pageShell;

  labelFor = (view) => {
    const automatic = this.pageShell.automaticContextView;
    return view.id === "follow-page"
      ? i18n("page_shell.context_follow_page", { view: i18n(automatic.label) })
      : i18n(view.label);
  };

  iconFor = (view) => view.icon ?? "table-columns";

  get options() {
    return [
      { ...this.pageShell.automaticContextView, id: "follow-page" },
      ...this.pageShell.contextViews,
    ];
  }

  get selectedOption() {
    return this.options.find(
      (view) => view.id === this.pageShell.contextPickerValue
    );
  }

  @action
  selectView(id, close) {
    this.pageShell.selectContextView(id);
    return close();
  }

  <template>
    <DMenu
      data-context-view={{this.pageShell.contextPickerValue}}
      @identifier="page-shell-context-picker"
      @placement="bottom-start"
      @triggerClass="btn-flat"
    >
      <:trigger>
        {{dIcon (this.iconFor this.selectedOption)}}
        <span class="d-button-label">{{this.labelFor
            this.selectedOption
          }}</span>
        {{dIcon "angle-down"}}
      </:trigger>
      <:content as |menu|>
        <DDropdownMenu as |dropdown|>
          {{#each this.options key="id" as |view|}}
            <dropdown.item>
              <DButton
                aria-current={{if
                  (eq this.pageShell.contextPickerValue view.id)
                  "true"
                }}
                data-context-view-option={{view.id}}
                @action={{fn this.selectView view.id menu.close}}
                @icon={{this.iconFor view}}
                @translatedLabel={{this.labelFor view}}
              />
            </dropdown.item>
          {{/each}}
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
