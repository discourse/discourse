import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getLoadedFaker } from "discourse/lib/load-faker";
import { i18n } from "discourse-i18n";

export default class extends Component {
  @tracked inline = true;
  @tracked hideHeader = false;
  @tracked dismissable = true;
  @tracked modalTagName = "div";
  @tracked title = i18n("styleguide.sections.modal.header");
  @tracked body = getLoadedFaker().faker.lorem.lines(5);
  @tracked subtitle = "";
  @tracked flash = "";
  @tracked flashType = "success";

  flashTypes = ["success", "info", "warning", "error"];
  modalTagNames = ["div", "form"];

  @action
  toggleHeader() {
    this.hideHeader = !this.hideHeader;
  }

  @action
  toggleInline() {
    this.inline = !this.inline;
    if (!this.inline) {
      // Make sure there is a way to dismiss the modal
      this.dismissable = true;
    }
  }

  @action
  toggleDismissable() {
    this.dismissable = !this.dismissable;
    if (!this.dismissable) {
      // Make sure there is a way to dismiss the modal
      this.inline = true;
    }
  }

  @action
  toggleShowFooter() {
    this.showFooter = !this.showFooter;
  }
}

{{! template-lint-disable no-potential-path-strings}}

<StyleguideExample @title="<DModal>">
  <Styleguide::Component>
    <DModal
      @closeModal={{fn (mut this.inline) true}}
      @hideHeader={{this.hideHeader}}
      @inline={{this.inline}}
      @title={{this.title}}
      @subtitle={{this.subtitle}}
      @flash={{this.flash}}
      @flashType={{this.flashType}}
      @errors={{this.errors}}
      @dismissable={{this.dismissable}}
    >
      <:body>
        {{this.body}}
      </:body>

      <:footer>
        {{i18n "styleguide.sections.modal.footer"}}
      </:footer>
    </DModal>
  </Styleguide::Component>

  <Styleguide::Controls>
    <Styleguide::Controls::Row @name="@hideHeader">
      <DToggleSwitch
        @state={{this.hideHeader}}
        {{on "click" this.toggleHeader}}
      />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="@inline">
      <DToggleSwitch @state={{this.inline}} {{on "click" this.toggleInline}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="@dismissable">
      <DToggleSwitch
        @state={{this.dismissable}}
        {{on "click" this.toggleDismissable}}
      />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="@tagName">
      <ComboBox
        @value={{this.modalTagName}}
        @content={{this.modalTagNames}}
        @onChange={{fn (mut this.modalTagName)}}
        @valueProperty={{null}}
        @nameProperty={{null}}
      />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="@title">
      <Input @value={{this.title}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="@subtitle">
      <Input @value={{this.subtitle}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="<:body>">
      <Textarea @value={{this.body}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="@flash">
      <Input @value={{this.flash}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="@flashType">
      <ComboBox
        @value={{this.flashType}}
        @content={{this.flashTypes}}
        @onChange={{fn (mut this.flashType)}}
        @valueProperty={{null}}
        @nameProperty={{null}}
      />
    </Styleguide::Controls::Row>
  </Styleguide::Controls>
</StyleguideExample>