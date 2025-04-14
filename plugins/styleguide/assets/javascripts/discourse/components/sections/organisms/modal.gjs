import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input, Textarea } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DModal from "discourse/components/d-modal";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { getLoadedFaker } from "discourse/lib/load-faker";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

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

  <template>
    {{! template-lint-disable no-potential-path-strings}}

    <StyleguideExample @title="<DModal>">
      <StyleguideComponent>
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
      </StyleguideComponent>

      <Controls>
        <Row @name="@hideHeader">
          <DToggleSwitch
            @state={{this.hideHeader}}
            {{on "click" this.toggleHeader}}
          />
        </Row>
        <Row @name="@inline">
          <DToggleSwitch
            @state={{this.inline}}
            {{on "click" this.toggleInline}}
          />
        </Row>
        <Row @name="@dismissable">
          <DToggleSwitch
            @state={{this.dismissable}}
            {{on "click" this.toggleDismissable}}
          />
        </Row>
        <Row @name="@tagName">
          <ComboBox
            @value={{this.modalTagName}}
            @content={{this.modalTagNames}}
            @onChange={{fn (mut this.modalTagName)}}
            @valueProperty={{null}}
            @nameProperty={{null}}
          />
        </Row>
        <Row @name="@title">
          <Input @value={{this.title}} />
        </Row>
        <Row @name="@subtitle">
          <Input @value={{this.subtitle}} />
        </Row>
        <Row @name="<:body>">
          <Textarea @value={{this.body}} />
        </Row>
        <Row @name="@flash">
          <Input @value={{this.flash}} />
        </Row>
        <Row @name="@flashType">
          <ComboBox
            @value={{this.flashType}}
            @content={{this.flashTypes}}
            @onChange={{fn (mut this.flashType)}}
            @valueProperty={{null}}
            @nameProperty={{null}}
          />
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
