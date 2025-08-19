/* eslint-disable ember/no-classic-components */
import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { observes, on as onDecorator } from "@ember-decorators/object";
import $ from "jquery";
import icon from "discourse/helpers/d-icon";
import groupAutocomplete from "discourse/lib/autocomplete/group";
import discourseComputed from "discourse/lib/decorators";
import { TextareaAutocompleteHandler } from "discourse/lib/textarea-text-manipulation";
import DAutocompleteModifier from "discourse/modifiers/d-autocomplete";
import { i18n } from "discourse-i18n";

export default class GroupSelector extends Component {
  @service siteSettings;

  @tracked selectedItems = [];

  @discourseComputed("placeholderKey")
  placeholder(placeholderKey) {
    return placeholderKey ? i18n(placeholderKey) : "";
  }

  get shouldHideInput() {
    return this.single && this.selectedItems.length > 0;
  }

  @observes("groupNames")
  _update() {
    if (this.canReceiveUpdates === "true") {
      this._initializeAutocomplete({ updateData: true });
    }
  }

  @onDecorator("didInsertElement")
  _initializeAutocomplete(opts) {
    const inputElement = this.element.querySelector("input");

    // Initialize selected items from groupNames
    this.initializeSelectedItems(opts);

    // Set up multi-select UI
    this.setupMultiSelectUI(inputElement, opts);

    if (!this.siteSettings.floatkit_autocomplete_input_fields) {
      this.setupJQueryAutocomplete(inputElement);
      return;
    }

    this.setupAutocomplete(inputElement);
  }

  initializeSelectedItems(opts) {
    if (opts?.updateData) {
      // For updates, keep existing selected items
      return;
    }

    const groupNames = this.groupNames;
    this.selectedItems = Array.isArray(groupNames)
      ? [...groupNames]
      : isEmpty(groupNames)
        ? []
        : [groupNames];
  }

  setupMultiSelectUI(inputElement) {
    // Clear input value
    inputElement.value = "";
  }

  removeSelectedItem(item) {
    const index = this.selectedItems.indexOf(item);
    if (index > -1) {
      this.selectedItems.splice(index, 1);
      this.selectedItems = [...this.selectedItems]; // Trigger reactivity
      this.notifyItemsChanged();

      // Focus input if single mode and no items
      if (this.single && this.selectedItems.length === 0) {
        const inputElement = this.element.querySelector("input");
        inputElement.focus();
      }
    }
  }

  addSelectedItem(item) {
    if (this.single) {
      this.selectedItems = [item];
    } else if (!this.selectedItems.includes(item)) {
      this.selectedItems.push(item);
    }

    this.selectedItems = [...this.selectedItems]; // Trigger reactivity
    this.notifyItemsChanged();

    // Clear input after selection
    const inputElement = this.element.querySelector("input");
    inputElement.value = "";
  }

  notifyItemsChanged() {
    if (this.onChange) {
      this.onChange(this.selectedItems.join(","));
    } else if (this.onChangeCallback) {
      this.onChangeCallback(this.groupNames, this.selectedItems);
    } else {
      this.set("groupNames", this.selectedItems.join(","));
    }
  }

  filteredGroupFinder(term) {
    return this.groupFinder(term).then((groups) => {
      if (!this.selectedItems || this.selectedItems.length === 0) {
        return groups;
      }

      return groups.filter((group) => {
        return !this.selectedItems.includes(group.name);
      });
    });
  }

  setupAutocomplete(inputElement) {
    const autocompleteHandler = new TextareaAutocompleteHandler(inputElement);

    DAutocompleteModifier.setupAutocomplete(
      getOwner(this),
      inputElement,
      autocompleteHandler,
      {
        debounced: true,
        template: groupAutocomplete,
        transformComplete: (g) => {
          // Instead of inserting into text, add to selected items
          this.addSelectedItem(g.name);
          return ""; // Return empty string to prevent text insertion
        },
        dataSource: (term) => this.filteredGroupFinder(term),
      }
    );
  }

  setupJQueryAutocomplete(inputElement) {
    $(inputElement).autocomplete({
      debounced: true,
      allowAny: false,
      items: this.selectedItems,
      single: this.single,
      fullWidthWrap: this.fullWidthWrap,
      updateData: false,
      onChangeItems: (items) => {
        this.selectedItems = [...items];
        this.notifyItemsChanged();
      },
      transformComplete: (g) => g.name,
      dataSource: (term) => this.filteredGroupFinder(term),
      template: groupAutocomplete,
    });
  }

  <template>
    <div
      class="ac-wrap clearfix {{if this.disabled 'disabled'}}"
      style={{unless this.fullWidthWrap "width: 200px"}}
    >
      {{#each this.selectedItems as |item|}}
        <div class="item">
          <span>
            {{item}}
            <a
              class="remove"
              href="#"
              {{on "click" (fn this.removeSelectedItem item)}}
            >
              {{icon "xmark"}}
            </a>
          </span>
        </div>
      {{/each}}

      <input
        placeholder={{this.placeholder}}
        class="group-selector {{if this.single 'fullwidth-input'}}"
        type="text"
        name="groups"
        style={{if this.shouldHideInput "display: none"}}
      />
    </div>
  </template>
}
