import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Textarea } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import { getLoadedFaker } from "discourse/lib/load-faker";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class extends Component {
  @tracked open = false;
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
  toggleDismissable() {
    this.dismissable = !this.dismissable;
  }

  @action
  toggleShowFooter() {
    this.showFooter = !this.showFooter;
  }

  @action
  openModal() {
    this.open = true;
  }

  @action
  closeModal() {
    this.open = false;
  }

  <template>
    {{! eslint-disable ember/template-no-potential-path-strings }}

    <StyleguideExample @title="<DModal>">
      <StyleguideComponent>
        <DButton
          @label="styleguide.sections.modal.open"
          @action={{this.openModal}}
        />

        {{#if this.open}}
          <DModal
            @closeModal={{this.closeModal}}
            @hideHeader={{this.hideHeader}}
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
        {{/if}}
      </StyleguideComponent>

      <Controls>
        <Row @name="@hideHeader">
          <DToggleSwitch
            @state={{this.hideHeader}}
            {{on "click" this.toggleHeader}}
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
          <input
            {{on "input" (withEventValue (fn (mut this.title)))}}
            type="text"
            value={{this.title}}
          />
        </Row>
        <Row @name="@subtitle">
          <input
            {{on "input" (withEventValue (fn (mut this.subtitle)))}}
            type="text"
            value={{this.subtitle}}
          />
        </Row>
        <Row @name="<:body>">
          <Textarea @value={{this.body}} />
        </Row>
        <Row @name="@flash">
          <input
            {{on "input" (withEventValue (fn (mut this.flash)))}}
            type="text"
            value={{this.flash}}
          />
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
