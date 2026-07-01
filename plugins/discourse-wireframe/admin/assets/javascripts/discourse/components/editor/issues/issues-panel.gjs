// @ts-check
import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * The left rail's Issues panel: a navigable list of the page's validation
 * problems, grouped by the outlet they live in. Each row names the failing
 * block and lists its author-facing messages; clicking (or pressing
 * Enter / Space on) a row selects that block and reveals it on the canvas,
 * so the author can jump straight from a problem to the block that owns it.
 *
 * The panel is a pure projection of `wireframeValidation.validationIssues`,
 * so it repaints live as the author fixes (or introduces) problems.
 */
export default class IssuesPanel extends Component {
  @service wireframeValidation;
  @service wireframeSelection;
  @service wireframeBlockReveal;

  /**
   * The flat issue list bucketed by outlet, so the template can render one
   * section per outlet. A plain getter (not `@cached`): the list is short
   * and re-grouping on each read keeps the tracked-stamp dependencies the
   * source getter opens intact, with no memoization to reason about.
   *
   * @returns {Array<{outletName: string, issues: Array<Object>}>}
   */
  get groups() {
    const byOutlet = new Map();
    for (const issue of this.wireframeValidation.validationIssues) {
      let bucket = byOutlet.get(issue.outletName);
      if (!bucket) {
        bucket = [];
        byOutlet.set(issue.outletName, bucket);
      }
      bucket.push(issue);
    }
    return [...byOutlet].map(([outletName, issues]) => ({
      outletName,
      issues,
    }));
  }

  /**
   * Selects the issue's block and flashes it into view. No-ops when the
   * issue has no `blockKey` (an unresolved block ref): passing a null key
   * to `selectBlock` would clear the current selection instead. Reveal
   * happens automatically off the selection change; the explicit flash
   * draws the eye once the block scrolls in.
   *
   * @param {Object} issue
   */
  @action
  selectIssue(issue) {
    if (!issue.blockKey) {
      return;
    }
    this.wireframeSelection.selectBlock({ key: issue.blockKey });
    this.wireframeBlockReveal.flash(issue.blockKey);
  }

  /**
   * Activates a keyboard-focused issue row on Enter or Space, matching the
   * native button contract for the row's `role="button"`. Prevents the
   * default Space-scroll so the key selects the block instead.
   *
   * @param {Object} issue
   * @param {KeyboardEvent} event
   */
  @action
  onRowKeydown(issue, event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.selectIssue(issue);
    }
  }

  <template>
    <div
      class="wireframe-issues"
      role="region"
      aria-label={{i18n "wireframe.chrome.panel_issues"}}
    >
      {{#if this.groups.length}}
        {{#each this.groups key="outletName" as |group|}}
          <div class="wireframe-issues__outlet">
            <div class="wireframe-issues__outlet-header">
              {{dIcon "cubes"}}
              <span class="wireframe-issues__outlet-name">
                {{group.outletName}}
              </span>
            </div>
            {{#each group.issues key="blockKey" as |issue|}}
              {{! Rows for a resolvable block are activatable (select + reveal);
                  a block with no key can't be addressed, so it renders as a
                  plain, non-interactive record of the problem. }}
              {{#if issue.blockKey}}
                <div
                  class={{dConcatClass
                    "wireframe-issues__item"
                    (if
                      (this.wireframeSelection.isBlockSelected issue.blockKey)
                      "--selected"
                    )
                  }}
                  role="button"
                  tabindex="0"
                  {{on "click" (fn this.selectIssue issue)}}
                  {{on "keydown" (fn this.onRowKeydown issue)}}
                >
                  <span class="wireframe-issues__item-icon">
                    {{dIcon "triangle-exclamation"}}
                  </span>
                  <span class="wireframe-issues__item-block">
                    {{issue.blockName}}
                  </span>
                  <ul class="wireframe-issues__messages">
                    {{#each issue.messages key="id" as |message|}}
                      <li>{{message.text}}</li>
                    {{/each}}
                  </ul>
                </div>
              {{else}}
                <div class="wireframe-issues__item --static">
                  <span class="wireframe-issues__item-icon">
                    {{dIcon "triangle-exclamation"}}
                  </span>
                  <span class="wireframe-issues__item-block">
                    {{issue.blockName}}
                  </span>
                  <ul class="wireframe-issues__messages">
                    {{#each issue.messages key="id" as |message|}}
                      <li>{{message.text}}</li>
                    {{/each}}
                  </ul>
                </div>
              {{/if}}
            {{/each}}
          </div>
        {{/each}}
      {{else}}
        <div class="panel-empty">
          {{i18n "wireframe.chrome.issues_empty"}}
        </div>
      {{/if}}
    </div>
  </template>
}
