/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import noop from "discourse/helpers/noop";
import discourseComputed, { bind } from "discourse/lib/decorators";
import {
  authorizedExtensions,
  authorizesAllExtensions,
} from "discourse/lib/uploads";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

// This picker is intended to be used with UppyUploadMixin or with
// ComposerUploadUppy, which is why there are no change events registered
// for the input. They are handled by the uppy mixins directly.
//
// However, if you provide an onFilesPicked action to this component, the change
// binding will still be added, and the file type will be validated here. This
// is sometimes useful if you need to do something outside the uppy upload with
// the file, such as directly using JSON or CSV data from a file in JS.
@classNames("pick-files-button")
export default class PickFilesButton extends Component {
  @service dialog;

  fileInputId = null;
  fileInputClass = null;
  fileInputDisabled = false;
  acceptedFormatsOverride = null;
  allowMultiple = false;
  showButton = false;

  didInsertElement() {
    super.didInsertElement(...arguments);

    if (this.onFilesPicked) {
      const fileInput = this.element.querySelector("input");
      this.set("fileInput", fileInput);
      fileInput.addEventListener("change", this.onChange, false);
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    if (this.onFilesPicked) {
      this.fileInput.removeEventListener("change", this.onChange);
    }
  }

  @bind
  onChange() {
    const files = this.fileInput.files;
    this._filesPicked(files);
  }

  @discourseComputed()
  acceptsAllFormats() {
    return (
      this.capabilities.isIOS ||
      authorizesAllExtensions(this.currentUser.staff, this.siteSettings)
    );
  }

  @discourseComputed()
  acceptedFormats() {
    // the acceptedFormatsOverride can be a list of extensions or mime types
    if (!isBlank(this.acceptedFormatsOverride)) {
      return this.acceptedFormatsOverride;
    }

    const extensions = authorizedExtensions(
      this.currentUser.staff,
      this.siteSettings
    );

    return extensions.map((ext) => `.${ext}`).join();
  }

  @action
  openSystemFilePicker() {
    this.fileInput.click();
  }

  _filesPicked(files) {
    if (!files || !files.length) {
      return;
    }

    if (!this._haveAcceptedTypes(files)) {
      const message = i18n("pick_files_button.unsupported_file_picked", {
        types: this.acceptedFileTypesString,
      });
      this.dialog.alert(message);
      return;
    }

    if (typeof this.onFilesPicked === "function") {
      this.onFilesPicked(files);
    }
  }

  _haveAcceptedTypes(files) {
    for (const file of files) {
      if (!this._hasAcceptedExtensionOrType(file)) {
        return false;
      }
    }
    return true;
  }

  _hasAcceptedExtensionOrType(file) {
    const extension = this._fileExtension(file.name);
    return (
      this.acceptedFormats.includes(`.${extension}`) ||
      this.acceptedFormats.includes(file.type)
    );
  }

  _fileExtension(fileName) {
    return fileName.split(".").pop();
  }

  <template>
    {{#if this.showButton}}
      <DButton
        @action={{this.openSystemFilePicker}}
        @label={{this.label}}
        @icon={{this.icon}}
        class={{concatClass this.class "btn-default"}}
      />
    {{/if}}
    {{#if this.acceptsAllFormats}}
      <input
        {{didInsert (or @registerFileInput (noop))}}
        type="file"
        id={{this.fileInputId}}
        class={{this.fileInputClass}}
        multiple={{this.allowMultiple}}
        disabled={{this.fileInputDisabled}}
      />
    {{else}}
      <input
        {{didInsert (or @registerFileInput (noop))}}
        type="file"
        id={{this.fileInputId}}
        class={{this.fileInputClass}}
        accept={{this.acceptedFormats}}
        multiple={{this.allowMultiple}}
        disabled={{this.fileInputDisabled}}
      />
    {{/if}}
  </template>
}
