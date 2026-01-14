import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { getURLWithCDN } from "discourse/lib/get-url";
import { isAudio, isImage, isVideo } from "discourse/lib/uploads";
import { i18n } from "discourse-i18n";

export default class ChatComposerUpload extends Component {
  get fileName() {
    return this.args.isDone
      ? this.args.upload.original_filename
      : this.args.upload.fileName;
  }

  get previewImageSrc() {
    return getURLWithCDN(this.args.upload?.url);
  }

  <template>
    {{#if @upload}}
      <div
        class={{concatClass
          "chat-composer-upload"
          (if (isImage this.fileName) "chat-composer-upload--image")
          (unless @isDone "chat-composer-upload--in-progress")
        }}
      >
        <div class="preview">
          {{#if (isImage this.fileName)}}
            {{#if @isDone}}
              <img class="preview-img" src={{this.previewImageSrc}} />
            {{else}}
              {{icon "far-image"}}
            {{/if}}
          {{else if (isVideo this.fileName)}}
            {{icon "file-video"}}
          {{else if (isAudio this.fileName)}}
            {{icon "file-audio"}}
          {{else}}
            {{icon "file-lines"}}
          {{/if}}
        </div>

        <span class="data">
          {{#unless (isImage this.fileName)}}
            <div class="top-data">
              <span class="file-name">{{this.fileName}}</span>
            </div>
          {{/unless}}

          <div class="bottom-data">
            {{#if @isDone}}
              {{#unless (isImage this.fileName)}}
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
