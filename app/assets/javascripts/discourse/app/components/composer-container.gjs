import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { and, or } from "truth-helpers";
import ComposerActionTitle from "discourse/components/composer-action-title";
import ComposerBody from "discourse/components/composer-body";
import ComposerEditor from "discourse/components/composer-editor";
import ComposerFullscreenPrompt from "discourse/components/composer-fullscreen-prompt";
import ComposerMessages from "discourse/components/composer-messages";
import ComposerSaveButton from "discourse/components/composer-save-button";
import ComposerTitle from "discourse/components/composer-title";
import ComposerToggles from "discourse/components/composer-toggles";
import ComposerUserSelector from "discourse/components/composer-user-selector";
import DButton from "discourse/components/d-button";
import LinkToInput from "discourse/components/link-to-input";
import PluginOutlet from "discourse/components/plugin-outlet";
import PopupInputTip from "discourse/components/popup-input-tip";
import TextField from "discourse/components/text-field";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import htmlClass from "discourse/helpers/html-class";
import htmlSafe from "discourse/helpers/html-safe";
import lazyHash from "discourse/helpers/lazy-hash";
import loadingSpinner from "discourse/helpers/loading-spinner";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import grippieDragResize from "discourse/modifiers/grippie-drag-resize";
import { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";
import MiniTagChooser from "select-kit/components/mini-tag-chooser";

export default class ComposerContainer extends Component {
  @service composer;
  @service site;
  @service appEvents;
  @service keyValueStore;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.composerResizeDebounceHandler);
  }

  @bind
  onResizeDragStart() {
    this.appEvents.trigger("composer:resize-started");
  }

  @bind
  onResizeDrag(size) {
    this.appEvents.trigger("composer:div-resizing");
    this.composer.set("composerHeight", `${size}px`);
    this.keyValueStore.set({
      key: "composerHeight",
      value: this.composer.composerHeight,
    });
    document.documentElement.style.setProperty(
      "--composer-height",
      size ? `${size}px` : ""
    );

    this._triggerComposerResized();
  }

  @bind
  onResizeDragEnd() {
    this.appEvents.trigger("composer:resize-ended");
  }

  _triggerComposerResized() {
    this.composerResizeDebounceHandler = discourseDebounce(
      this,
      this.composerResized,
      300
    );
  }

  composerResized() {
    this.appEvents.trigger("composer:resized");
  }

  <template>
    <ComposerBody
      @composer={{this.composer.model}}
      @showPreview={{this.composer.isPreviewVisible}}
      @openIfDraft={{this.composer.openIfDraft}}
      @typed={{this.composer.typed}}
      @cancelled={{this.composer.cancelled}}
      @save={{this.composer.saveAction}}
    >
      <div
        class="grippie"
        {{grippieDragResize
          "#reply-control"
          "top"
          (hash
            onResizeStart=this.onResizeDragStart
            onThrottledDrag=this.onResizeDrag
            onResizeEnd=this.onResizeDragEnd
          )
        }}
      ></div>
      {{#if this.composer.visible}}
        {{htmlClass (if this.composer.isPreviewVisible "composer-has-preview")}}

        {{#unless this.site.mobileView}}
          <ComposerMessages
            @composer={{this.composer.model}}
            @messageCount={{this.composer.messageCount}}
            @addLinkLookup={{this.composer.addLinkLookup}}
          />
        {{/unless}}

        {{#if this.composer.showFullScreenPrompt}}
          <ComposerFullscreenPrompt
            @removeFullScreenExitPrompt={{this.composer.removeFullScreenExitPrompt}}
          />
        {{/if}}

        {{#if this.composer.model.viewOpenOrFullscreen}}
          <div
            role="dialog"
            aria-label={{this.composer.ariaLabel}}
            class="reply-area
              {{if this.composer.canEditTags 'with-tags' 'without-tags'}}
              {{if
                this.composer.hasFormTemplate
                'with-form-template'
                'without-form-template'
              }}
              {{if
                this.composer.model.showCategoryChooser
                'with-category'
                'without-category'
              }}"
          >
            <span class="composer-open-plugin-outlet-container">
              <PluginOutlet
                @name="composer-open"
                @connectorTagName="div"
                @outletArgs={{lazyHash model=this.composer.model}}
              />
            </span>

            <div class="reply-to">
              {{#unless this.composer.model.viewFullscreen}}
                <div class="reply-details">
                  <ComposerActionTitle
                    @model={{this.composer.model}}
                    @canWhisper={{this.composer.canWhisper}}
                  />

                  <PluginOutlet
                    @name="composer-action-after"
                    @outletArgs={{lazyHash model=this.composer.model}}
                  />

                  {{#if this.site.desktopView}}
                    {{#if this.composer.model.unlistTopic}}
                      <span class="unlist">({{i18n "composer.unlist"}})</span>
                    {{/if}}
                    {{#if this.composer.isWhispering}}
                      {{#if this.composer.model.noBump}}
                        <span class="no-bump">{{icon "anchor"}}</span>
                      {{/if}}
                    {{/if}}
                  {{/if}}

                  {{#if this.composer.canEdit}}
                    <LinkToInput
                      @onClick={{this.composer.displayEditReason}}
                      @showInput={{this.composer.showEditReason}}
                      @icon="circle-info"
                      class="display-edit-reason"
                    >
                      <TextField
                        @value={{this.composer.editReason}}
                        @id="edit-reason"
                        @maxlength="255"
                        @placeholderKey="composer.edit_reason_placeholder"
                      />
                    </LinkToInput>
                  {{/if}}
                </div>
              {{/unless}}

              <PluginOutlet
                @name="before-composer-controls"
                @outletArgs={{lazyHash model=this.composer.model}}
              />

              <ComposerToggles
                @composeState={{this.composer.model.composeState}}
                @showToolbar={{this.composer.showToolbar}}
                @toggleComposer={{this.composer.toggle}}
                @toggleToolbar={{this.composer.toggleToolbar}}
                @toggleFullscreen={{this.composer.fullscreenComposer}}
                @disableTextarea={{this.composer.disableTextarea}}
              />
            </div>

            <ComposerEditor>
              <div class="composer-fields">
                <PluginOutlet
                  @name="before-composer-fields"
                  @outletArgs={{lazyHash model=this.composer.model}}
                />
                {{#unless this.composer.model.viewFullscreen}}
                  {{#if this.composer.model.canEditTitle}}
                    {{#if this.composer.model.creatingPrivateMessage}}
                      <div class="user-selector">
                        <ComposerUserSelector
                          @topicId={{this.composer.topicModel.id}}
                          @recipients={{this.composer.model.targetRecipients}}
                          @hasGroups={{this.composer.model.hasTargetGroups}}
                          @focusTarget={{this.composer.focusTarget}}
                          class={{concatClass
                            "users-input"
                            (if this.composer.showWarning "can-warn")
                          }}
                        />
                        {{#if this.composer.showWarning}}
                          <label class="add-warning">
                            <Input
                              @type="checkbox"
                              @checked={{this.composer.model.isWarning}}
                            />
                            <span>{{i18n "composer.add_warning"}}</span>
                          </label>
                        {{/if}}
                      </div>
                    {{/if}}

                    <div
                      class="title-and-category
                        {{if this.composer.isPreviewVisible 'with-preview'}}"
                    >
                      <ComposerTitle
                        @composer={{this.composer.model}}
                        @lastValidatedAt={{this.composer.lastValidatedAt}}
                        @focusTarget={{this.composer.focusTarget}}
                      />

                      {{#if this.composer.model.showCategoryChooser}}
                        <div class="category-input">
                          <CategoryChooser
                            @value={{this.composer.model.categoryId}}
                            @onChange={{this.composer.updateCategory}}
                            @options={{hash
                              disabled=this.composer.disableCategoryChooser
                              scopedCategoryId=this.composer.scopedCategoryId
                              prioritizedCategoryId=this.composer.prioritizedCategoryId
                            }}
                          />
                          <PluginOutlet
                            @name="after-composer-category-input"
                            @outletArgs={{lazyHash
                              composer=this.composer.model
                            }}
                          />
                          <PopupInputTip
                            @validation={{this.composer.categoryValidation}}
                          />
                        </div>
                      {{/if}}

                      {{#if this.composer.canEditTags}}
                        <div class="tags-input">
                          <MiniTagChooser
                            @value={{this.composer.model.tags}}
                            @onChange={{fn (mut this.composer.model.tags)}}
                            @options={{hash
                              disabled=this.composer.disableTagsChooser
                              categoryId=this.composer.model.categoryId
                              minimum=this.composer.model.minimumRequiredTags
                            }}
                          />
                          <PluginOutlet
                            @name="after-composer-tag-input"
                            @outletArgs={{lazyHash
                              composer=this.composer.model
                            }}
                          />
                          <PopupInputTip
                            @validation={{this.composer.tagValidation}}
                          />
                        </div>
                      {{/if}}

                      <PluginOutlet
                        @name="after-title-and-category"
                        @outletArgs={{lazyHash
                          model=this.composer.model
                          tagValidation=this.composer.tagValidation
                          canEditTags=this.composer.canEditTags
                          disabled=this.composer.disableTagsChooser
                        }}
                      />
                    </div>
                  {{/if}}

                  <span>
                    <PluginOutlet
                      @name="composer-fields"
                      @connectorTagName="div"
                      @outletArgs={{lazyHash
                        model=this.composer.model
                        showPreview=this.composer.isPreviewVisible
                      }}
                    />
                  </span>
                {{/unless}}
              </div>
            </ComposerEditor>

            <span>
              <PluginOutlet
                @name="composer-after-composer-editor"
                @outletArgs={{lazyHash model=this.composer.model}}
              />
            </span>

            <div class="submit-panel">
              <span>
                <PluginOutlet
                  @name="composer-fields-below"
                  @connectorTagName="div"
                  @outletArgs={{lazyHash model=this.composer.model}}
                />
              </span>

              <div class="save-or-cancel">
                <ComposerSaveButton
                  @action={{this.composer.saveAction}}
                  @icon={{this.composer.saveIcon}}
                  @label={{this.composer.saveLabel}}
                  @forwardEvent={{true}}
                  @disableSubmit={{this.composer.disableSubmit}}
                />

                {{#if this.site.mobileView}}
                  <DButton
                    @action={{this.composer.cancel}}
                    class="cancel btn-transparent"
                    @icon={{if this.composer.canEdit "xmark" "trash-can"}}
                    @preventFocus={{true}}
                    @title="close"
                  />
                {{else}}
                  <DButton
                    @action={{this.composer.cancel}}
                    class="cancel btn-transparent"
                    @preventFocus={{true}}
                    @title="close"
                    @label="close"
                  />
                {{/if}}

                {{#if this.site.mobileView}}

                  {{#if this.composer.model.noBump}}
                    <span class="no-bump">{{icon "anchor"}}</span>
                  {{/if}}
                {{/if}}

                <span>
                  <PluginOutlet
                    @name="composer-after-save-or-cancel"
                    @outletArgs={{lazyHash model=this.composer.model}}
                  />
                </span>
              </div>

              {{#if this.site.mobileView}}
                <span>
                  <PluginOutlet
                    @name="composer-mobile-buttons-bottom"
                    @outletArgs={{lazyHash model=this.composer.model}}
                  />
                </span>

                {{#if this.composer.allowUpload}}
                  <a
                    id="mobile-file-upload"
                    class="btn btn-default no-text mobile-file-upload
                      {{if this.composer.isUploading 'hidden'}}"
                    aria-label={{i18n "composer.upload_title"}}
                  >
                    {{icon this.composer.uploadIcon}}
                  </a>
                {{/if}}

                {{#if this.composer.allowPreview}}
                  <a
                    href
                    class="btn btn-default no-text mobile-preview"
                    title={{i18n "composer.show_preview"}}
                    {{on "click" this.composer.togglePreview}}
                    aria-label={{i18n "composer.show_preview"}}
                  >
                    {{icon "desktop"}}
                  </a>
                {{/if}}

                {{#if this.composer.isPreviewVisible}}
                  <DButton
                    @action={{this.composer.togglePreview}}
                    @title="composer.hide_preview"
                    @ariaLabel="composer.hide_preview"
                    @icon="pencil"
                    class="hide-preview"
                  />
                {{/if}}
              {{/if}}

              {{#if
                (or this.composer.isUploading this.composer.isProcessingUpload)
              }}
                <div id="file-uploading">
                  {{#if this.composer.isProcessingUpload}}
                    {{loadingSpinner size="small"}}<span>{{i18n
                        "upload_selector.processing"
                      }}</span>
                  {{else}}
                    {{loadingSpinner size="small"}}<span>{{i18n
                        "upload_selector.uploading"
                      }}
                      {{this.composer.uploadProgress}}%</span>
                  {{/if}}

                  {{#if this.composer.isCancellable}}
                    <a
                      href
                      id="cancel-file-upload"
                      {{on "click" this.composer.cancelUpload}}
                    >{{icon "xmark"}}</a>
                  {{/if}}
                </div>
              {{/if}}

              {{#if this.composer.model.draftStatus}}
                <div
                  class={{if this.composer.isUploading "hidden"}}
                  id="draft-status"
                >
                  <span
                    class="draft-error"
                    title={{this.composer.model.draftStatus}}
                  >
                    {{#if this.composer.model.draftConflictUser}}
                      {{avatar
                        this.composer.model.draftConflictUser
                        imageSize="small"
                      }}
                      {{icon "user-pen"}}
                    {{else}}
                      {{icon "triangle-exclamation"}}
                    {{/if}}
                    {{#if this.site.desktopView}}
                      {{this.composer.model.draftStatus}}
                    {{/if}}
                  </span>
                </div>
              {{/if}}

              {{#if (and this.composer.allowPreview this.site.desktopView)}}
                <DButton
                  @action={{this.composer.togglePreview}}
                  @translatedTitle={{this.composer.toggleText}}
                  @icon="angles-left"
                  class={{concatClass
                    "btn-transparent btn-mini-toggle toggle-preview"
                    (unless this.composer.isPreviewVisible "active")
                  }}
                />
              {{/if}}
            </div>
          </div>
        {{else}}
          <div class="saving-text">
            {{#if this.composer.model.createdPost}}
              {{i18n "composer.saved"}}
              <a
                href={{this.composer.createdPost.url}}
                {{on "click" this.composer.viewNewReply}}
                class="permalink"
              >{{i18n "composer.view_new_post"}}</a>
            {{else}}
              {{i18n "composer.saving"}}
              {{loadingSpinner size="small"}}
            {{/if}}
          </div>

          <div class="draft-text">
            {{#if this.composer.model.topic}}
              {{icon "share"}}
              {{htmlSafe this.composer.draftTitle}}
            {{else}}
              {{i18n "composer.saved_draft"}}
            {{/if}}
          </div>

          <ComposerToggles
            @composeState={{this.composer.model.composeState}}
            @toggleFullscreen={{this.composer.openIfDraft}}
            @toggleComposer={{this.composer.toggle}}
            @toggleToolbar={{this.composer.toggleToolbar}}
          />
        {{/if}}
      {{/if}}
    </ComposerBody>
  </template>
}
