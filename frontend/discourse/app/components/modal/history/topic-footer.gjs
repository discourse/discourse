import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import VisibilityMenu from "./visibility-menu.gjs";

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
    {{#if @showUnlistedToggle}}
      <DToggleSwitch
        class="show-unlisted-revisions"
        disabled={{@loading}}
        @label="post.revisions.show_all_edits"
        @state={{@includeUnlisted}}
        {{on "click" @toggleIncludeUnlisted}}
      />
    {{/if}}

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

      <VisibilityMenu
        @canPermanentlyDelete={{@canPermanentlyDelete}}
        @disabled={{@loading}}
        @onChange={{@changeVisibility}}
        @onPermanentlyDelete={{@permanentlyDeleteVersions}}
        @visibility={{@visibility}}
      />
    {{/if}}
  </div>
</template>;

export default TopicFooter;
