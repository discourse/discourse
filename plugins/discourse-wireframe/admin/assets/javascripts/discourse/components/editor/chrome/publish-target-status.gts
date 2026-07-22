import Component from "@glimmer/component";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import WireframePublishTargetService, {
  type ActiveThemeTarget,
  type PublishTarget,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-publish-target";
import type WireframeStagingService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-staging";

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
  /** Exposes publish-target resolution state. */
  @service declare wireframeStaging: WireframeStagingService;
  /** Resolves the themes receiving staged changes. */
  @service declare wireframePublishTarget: WireframePublishTargetService;

  /** Publish destinations represented by the current staged changes. */
  get targets(): PublishTarget[] {
    return this.wireframePublishTarget.publishTargets;
  }

  /**
   * The single target to name, or null when several themes are involved. Falls
   * back to the active theme when nothing is edited yet.
   */
  get singleTarget(): ActiveThemeTarget | PublishTarget | null {
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
   */
  get hasTarget(): boolean {
    return (
      this.targets.length > 0 ||
      this.wireframePublishTarget.activeThemeTarget != null
    );
  }

  /**
   * Whether any target can't be published to directly.
   */
  get hasBlocked(): boolean {
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

  /** Translated description of the resolved publish destination. */
  get label(): string {
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
