// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Passive topbar status naming where this session's changes will publish. Before
 * anything is edited it names the active theme (the prospective target); once
 * outlets are edited it reflects their actual owner themes — a single theme by
 * name, or a count when the edits span several. A warning treatment appears when
 * any target can't be published to directly (a core or Git theme).
 *
 * Purely informational — the actual publish flow lives behind the Save button's
 * review drawer, so this is not a button and carries no click action.
 */
export default class PublishTargetStatus extends Component {
  @service wireframeStaging;
  @service wireframePublishTarget;

  get targets() {
    return this.wireframePublishTarget.publishTargets;
  }

  /**
   * The single target to name, or null when several themes are involved. Falls
   * back to the active theme when nothing is edited yet.
   *
   * @returns {Object|null}
   */
  get singleTarget() {
    if (this.targets.length === 1) {
      return this.targets[0];
    }
    if (this.targets.length === 0) {
      return this.wireframePublishTarget.activeThemeTarget;
    }
    return null;
  }

  /**
   * Whether there's anything to show (a resolvable target).
   *
   * @returns {boolean}
   */
  get hasTarget() {
    return (
      this.targets.length > 0 ||
      this.wireframePublishTarget.activeThemeTarget != null
    );
  }

  /**
   * Whether any target can't be published to directly.
   *
   * @returns {boolean}
   */
  get hasBlocked() {
    // While the companion lookup is still in flight, don't show the blocked
    // warning — it may resolve to a publishable companion.
    if (this.wireframeStaging.publishTargetResolving) {
      return false;
    }
    if (this.singleTarget) {
      return !this.singleTarget.publishable;
    }
    return this.targets.some((group) => !group.publishable);
  }

  /** @returns {string} */
  get label() {
    if (this.singleTarget) {
      return i18n("wireframe.review.publishing_to_one", {
        theme:
          this.singleTarget.themeName ?? i18n("wireframe.review.this_theme"),
      });
    }
    return i18n("wireframe.review.publishing_to_many", {
      count: this.targets.length,
    });
  }

  <template>
    {{#if this.hasTarget}}
      <div
        class={{dConcatClass
          "wireframe-target-status"
          (if this.hasBlocked "--blocked")
        }}
        title={{this.label}}
      >
        {{dIcon (if this.hasBlocked "triangle-exclamation" "cloud-arrow-up")}}
        <span class="wireframe-target-status__label">{{this.label}}</span>
      </div>
    {{/if}}
  </template>
}
