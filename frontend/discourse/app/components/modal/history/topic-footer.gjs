import { trustHTML } from "@ember/template";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";

const TopicFooter = <template>
  <div id="revision-controls">
    <div class="revision-controls--back">
      <DButton
        class="btn-default first-revision"
        @action={{@loadFirstVersion}}
        @disabled={{@loadFirstDisabled}}
        @icon="backward-fast"
        @title="post.revisions.controls.first"
      />
      <DButton
        class="btn-default previous-revision"
        @action={{@loadPreviousVersion}}
        @disabled={{@loadPreviousDisabled}}
        @icon="backward"
        @title="post.revisions.controls.previous"
      />
    </div>
    <div class={{unless @displayRevisions "invisible"}} id="revision-numbers">
      <DConditionalLoadingSpinner @condition={{@loading}} @size="small">
        {{trustHTML @revisionsText}}
      </DConditionalLoadingSpinner>
    </div>
    <div class="revision-controls--forward">
      <DButton
        class="btn-default next-revision"
        @action={{@loadNextVersion}}
        @disabled={{@loadNextDisabled}}
        @icon="forward"
        @title="post.revisions.controls.next"
      />
      <DButton
        class="btn-default last-revision"
        @action={{@loadLastVersion}}
        @disabled={{@loadLastDisabled}}
        @icon="forward-fast"
        @title="post.revisions.controls.last"
      />
    </div>
  </div>

  <div id="revision-footer-buttons">
    {{#if @displayEdit}}
      <DButton
        class="btn-default edit-post"
        @action={{@editPost}}
        @icon="pencil"
        @label={{@editButtonLabel}}
      />
    {{/if}}

    {{#if @isStaff}}
      {{#if @revertToRevisionText}}
        <DButton
          class="btn-danger revert-to-version"
          @action={{@revertToVersion}}
          @disabled={{@loading}}
          @icon="arrow-rotate-left"
          @translatedLabel={{@revertToRevisionText}}
        />
      {{/if}}

      {{#if @model.previous_hidden}}
        <DButton
          class="btn-default show-revision"
          @action={{@showVersion}}
          @disabled={{@loading}}
          @icon="far-eye"
          @label="post.revisions.controls.show"
        />
      {{else}}
        <DButton
          class="btn-danger hide-revision"
          @action={{@hideVersion}}
          @disabled={{@loading}}
          @icon="far-eye-slash"
          @label="post.revisions.controls.hide"
        />
      {{/if}}

      {{#if (and @canPermanentlyDelete @model.previous_hidden)}}
        <DButton
          class="btn-danger destroy-revision"
          @action={{@permanentlyDeleteVersions}}
          @disabled={{@loading}}
          @icon="trash-can"
          @label="post.revisions.controls.destroy"
        />
      {{/if}}
    {{/if}}
  </div>
</template>;

export default TopicFooter;
