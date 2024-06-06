import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import FormMeta from "form-kit/components/form/meta";
import FormText from "form-kit/components/form/text";
import UppyImageUploader from "discourse/components/uppy-image-uploader";

export default class FkControlImage extends Component {
  @action
  setImage(upload) {
    this.args.setValue(upload.url);
  }

  @action
  removeImage() {
    this.args.setValue(undefined);
  }

  @action
  handleDestroy() {
    this.args.setValue(undefined);
  }

  <template>
    {{#if @label}}
      <label class="d-form-select-label" for={{@name}}>
        {{@label}}
        {{#unless @required}}
          <span class="d-form-field__optional">(Optional)</span>
        {{/unless}}
      </label>
    {{/if}}

    {{#if @help}}
      <FormText>{{@help}}</FormText>
    {{/if}}

    <UppyImageUploader
      @id={{concat "d-form-image-input-" @name}}
      @imageUrl={{@value}}
      @onUploadDone={{this.setImage}}
      @onUploadDeleted={{this.removeImage}}
      class="d-form-image-input no-repeat contain-image"
      {{willDestroy this.handleDestroy}}
    />

    <FormMeta
      @description={{@description}}
      @disabled={{@disabled}}
      @value={{@value}}
      @maxLength={{@maxLength}}
      @errorId={{@errorId}}
      @errors={{@errors}}
    />
  </template>
}
