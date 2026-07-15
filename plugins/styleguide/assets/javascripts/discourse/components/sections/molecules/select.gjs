import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import StyleguideExample from "../../styleguide-example";

function delay(signal, milliseconds = 750) {
  return new Promise((resolve, reject) => {
    const onAbort = () => {
      clearTimeout(timeout);
      reject(signal.reason ?? new DOMException("Aborted", "AbortError"));
    };
    const timeout = setTimeout(() => {
      signal.removeEventListener("abort", onAbort);
      resolve();
    }, milliseconds);

    if (signal.aborted) {
      onAbort();
    } else {
      signal.addEventListener("abort", onAbort, { once: true });
    }
  });
}

export default class Select extends Component {
  @tracked asyncButtonValue = null;
  @tracked defaultValue = null;
  @tracked emptyValue = null;
  @tracked errorValue = null;
  @tracked multiValue = [];
  @tracked staticValue = null;

  errorRequestCount = 0;

  defaultCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  asyncButtonCode = `<DSelect
  @load={{this.loadOptions}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  staticCode = `<DSelect
  @items={{this.items}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="static"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  multiCode = `<DSelect
  @items={{this.items}}
  @multiple={{true}}
  @value={{this.value}}
  @onChange={{this.onChange}}
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  emptyCode = `<DSelect
  @load={{this.loadEmpty}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  errorCode = `<DSelect
  @load={{this.loadWithRetry}}
  @value={{this.value}}
  @onChange={{this.onChange}}
  @variant="button"
>
  <:selection as |item|>{{item.name}}</:selection>
  <:item as |item|>{{item.name}}</:item>
</DSelect>`;

  get items() {
    return this.args.dummy.options;
  }

  filterItems(filter) {
    const normalizedFilter = filter.toLowerCase();
    return this.items.filter((item) =>
      item.name.toLowerCase().includes(normalizedFilter)
    );
  }

  @action
  async loadEmpty(_filter, { signal }) {
    await delay(signal);
    return [];
  }

  @action
  async loadOptions(filter, { signal }) {
    await delay(signal, 1200);
    return this.filterItems(filter);
  }

  @action
  async loadWithRetry(filter, { signal }) {
    await delay(signal);
    this.errorRequestCount++;

    if (this.errorRequestCount === 1) {
      throw new Error(i18n("styleguide.sections.select.request_error"));
    }

    return this.filterItems(filter);
  }

  @action
  updateAsyncButton(value) {
    this.asyncButtonValue = value;
  }

  @action
  updateDefault(value) {
    this.defaultValue = value;
  }

  @action
  updateEmpty(value) {
    this.emptyValue = value;
  }

  @action
  updateError(value) {
    this.errorValue = value;
  }

  @action
  updateMulti(value) {
    this.multiValue = value;
  }

  @action
  updateStatic(value) {
    this.staticValue = value;
  }

  <template>
    <p class="section-description">
      {{i18n "styleguide.sections.select.description"}}
    </p>
    <p class="styleguide-note select-examples__mobile-note">
      {{i18n "styleguide.sections.select.mobile_guidance"}}
    </p>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.default_example"}}
      @code={{this.defaultCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @value={{this.defaultValue}}
          @onChange={{this.updateDefault}}
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.async_button_example"}}
      @code={{this.asyncButtonCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @load={{this.loadOptions}}
          @value={{this.asyncButtonValue}}
          @onChange={{this.updateAsyncButton}}
          @variant="button"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.static_example"}}
      @code={{this.staticCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @value={{this.staticValue}}
          @onChange={{this.updateStatic}}
          @variant="static"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.multi_example"}}
      @code={{this.multiCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @items={{this.items}}
          @multiple={{true}}
          @value={{this.multiValue}}
          @onChange={{this.updateMulti}}
          @placeholder={{i18n "styleguide.sections.select.multi_placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.empty_example"}}
      @code={{this.emptyCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @load={{this.loadEmpty}}
          @value={{this.emptyValue}}
          @onChange={{this.updateEmpty}}
          @variant="button"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
          @noResultsLabel={{i18n "styleguide.sections.select.empty_label"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title={{i18n "styleguide.sections.select.error_example"}}
      @code={{this.errorCode}}
    >
      <div class="select-examples__control">
        <DSelect
          @load={{this.loadWithRetry}}
          @value={{this.errorValue}}
          @onChange={{this.updateError}}
          @variant="button"
          @placeholder={{i18n "styleguide.sections.select.placeholder"}}
        >
          <:selection as |item|>{{item.name}}</:selection>
          <:item as |item|>{{item.name}}</:item>
        </DSelect>
      </div>
    </StyleguideExample>
  </template>
}
