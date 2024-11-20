import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { isImage } from "discourse/lib/uploads";
import dIcon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatComposerUpload extends Component {
  get isImage() {
    return isImage(
      this.args.upload.original_filename || this.args.upload.fileName
    );
  }

  get fileName() {
    return this.args.isDone
      ? this.args.upload.original_filename
      : this.args.upload.fileName;
  }

  <template>
    {{#if @upload}}
      <div
        class={{concatClass
          "chat-composer-upload"
          (if this.isImage "chat-composer-upload--image")
          (unless @isDone "chat-composer-upload--in-progress")
        }}
      >
        <div class="preview">
          {{#if this.isImage}}
            {{#if @isDone}}
              <img class="preview-img" src={{@upload.short_path}} />
            {{else}}
              {{dIcon "far-image"}}
            {{/if}}
          {{else}}
            {{dIcon "file-lines"}}
          {{/if}}
        </div>

        <span class="data">
          {{#unless this.isImage}}
            <div class="top-data">
              <span class="file-name">{{this.fileName}}</span>
            </div>
          {{/unless}}

          <div class="bottom-data">
            {{#if @isDone}}
              {{#unless this.isImage}}
                <span class="extension-pill">{{@upload.extension}}</span>
              {{/unless}}
            {{else}}
              {{#if @upload.processing}}
                <span class="processing">{{i18n "processing"}}</span>
              {{else}}
                <span class="uploading">{{i18n "uploading"}}</span>
              {{/if}}

              <progress
                class="upload-progress"
                id="file"
                max="100"
                value={{@upload.progress}}
              ></progress>
            {{/if}}
          </div>
        </span>

        <DButton
          @action={{@onCancel}}
          @icon="xmark"
          @title="chat.remove_upload"
          class="btn-flat chat-composer-upload__remove-btn"
        />
      </div>
    {{/if}}
  </template>
}
