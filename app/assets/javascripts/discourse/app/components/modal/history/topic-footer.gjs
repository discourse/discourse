import { htmlSafe } from "@ember/template";
import { and } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";

const TopicFooter = <template>
  <div id="revision-controls">
    <div class="revision-controls--back">
      <DButton
        class="btn-default first-revision"
        @action={{@loadFirstVersion}}
        @icon="backward-fast"
        @title="post.revisions.controls.first"
        @disabled={{@loadFirstDisabled}}
      />
      <DButton
        class="btn-default previous-revision"
        @action={{@loadPreviousVersion}}
        @icon="backward"
        @title="post.revisions.controls.previous"
        @disabled={{@loadPreviousDisabled}}
      />
    </div>
    <div id="revision-numbers" class={{unless @displayRevisions "invisible"}}>
      <ConditionalLoadingSpinner @condition={{@loading}} @size="small">
        {{htmlSafe @revisionsText}}
      </ConditionalLoadingSpinner>
    </div>
    <div class="revision-controls--forward">
      <DButton
        class="btn-default next-revision"
        @action={{@loadNextVersion}}
        @icon="forward"
        @title="post.revisions.controls.next"
        @disabled={{@loadNextDisabled}}
      />
      <DButton
        class="btn-default last-revision"
        @action={{@loadLastVersion}}
        @icon="forward-fast"
        @title="post.revisions.controls.last"
        @disabled={{@loadLastDisabled}}
      />
    </div>
  </div>

  <div id="revision-footer-buttons">
    {{#if @displayEdit}}
      <DButton
        @action={{@editPost}}
        @icon="pencil"
        class="btn-default edit-post"
        @label={{@editButtonLabel}}
      />
    {{/if}}

    {{#if @isStaff}}
      {{#if @revertToRevisionText}}
        <DButton
          @action={{@revertToVersion}}
          @icon="arrow-rotate-left"
          @translatedLabel={{@revertToRevisionText}}
          class="btn-danger revert-to-version"
          @disabled={{@loading}}
        />
      {{/if}}

      {{#if @model.previous_hidden}}
        <DButton
          @action={{@showVersion}}
          @icon="far-eye"
          @label="post.revisions.controls.show"
          class="btn-default show-revision"
          @disabled={{@loading}}
        />
      {{else}}
        <DButton
          @action={{@hideVersion}}
          @icon="far-eye-slash"
          @label="post.revisions.controls.hide"
          class="btn-danger hide-revision"
          @disabled={{@loading}}
        />
      {{/if}}

      {{#if (and @canPermanentlyDelete @model.previous_hidden)}}
        <DButton
          @action={{@permanentlyDeleteVersions}}
          @icon="trash-can"
          @label="post.revisions.controls.destroy"
          class="btn-danger destroy-revision"
          @disabled={{@loading}}
        />
      {{/if}}
    {{/if}}
  </div>
</template>;

export default TopicFooter;
