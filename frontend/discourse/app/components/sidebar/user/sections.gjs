import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import BlockOutlet from "discourse/blocks/block-outlet";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import discourseLater from "discourse/lib/later";
import {
  extractDroppedWebLink,
  WEB_LINK_ADOPTION,
  WEB_LINK_KINDS,
  webLinkPayload,
} from "discourse/lib/sidebar/link-drop";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import dDragDwell from "discourse/ui-kit/modifiers/d-drag-dwell";
import { i18n } from "discourse-i18n";
import ApiSections from "../api-sections";
import CategoriesSection from "./categories-section";
import CustomSections from "./custom-sections";
import TagsSection from "./tags-section";

/**
 * How long the revealed drop zone stays inert. Revealing shifts everything
 * below it down, so a pointer resting there would land inside the zone the
 * moment it appears; the beat lets the user see it before it can take a drop.
 */
const ZONE_ARM_DELAY = 250;

export default class SidebarUserSections extends Component {
  @service currentUser;
  @service modal;

  /** Whether the new-section drop zone is on screen. */
  @tracked zoneRevealed = false;

  /** Whether the zone can take a drop yet. See `ZONE_ARM_DELAY`. */
  @tracked zoneArmed = false;

  /** Whether the dragged link is over the zone. */
  @tracked zoneHovered = false;

  #armTimer = null;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#armTimer);
  }

  /**
   * Arms the reveal dwell: only where link drop is enabled at all, and only
   * for a drag that declares a real URL. A drag carrying only text may well
   * turn out to hold nothing droppable.
   */
  @action
  canDwellForNewSection({ source }) {
    const payload = webLinkPayload(source);
    return (
      Boolean(this.args.enableLinkDrop) &&
      payload.containsURLs() &&
      !payload.containsFiles()
    );
  }

  @action
  revealZone() {
    this.zoneRevealed = true;
    this.#armTimer = discourseLater(() => {
      this.zoneArmed = true;
    }, ZONE_ARM_DELAY);
  }

  /**
   * Hides the zone for every way the dwell ends: the drop, if there was one,
   * has already been dispatched to its target by the time the dwell monitor
   * reports the drag over.
   */
  @action
  hideZone() {
    cancel(this.#armTimer);
    this.#armTimer = null;
    this.zoneRevealed = false;
    this.zoneArmed = false;
    this.zoneHovered = false;
  }

  @action
  trackZoneHover() {
    this.zoneHovered = true;
  }

  @action
  clearZoneHover() {
    this.zoneHovered = false;
  }

  /**
   * Files are their own drag with their own destinations, and this zone only
   * knows what to do with a URL.
   */
  @action
  canDropLink({ source }) {
    return !webLinkPayload(source).containsFiles();
  }

  @action
  createSectionFromLink({ source }) {
    const link = extractDroppedWebLink(webLinkPayload(source));
    if (!link) {
      return;
    }

    // No focused link: the link arrived filled in, and the title is the one
    // field the new section still needs, so the form's default focus lands
    // there.
    this.modal.show(SidebarSectionForm, {
      model: { link },
    });
  }

  <template>
    {{! This is the element that scrolls, so a link dragged in can only reach a
        section below the fold if the scrolling happens here. Both origins are
        named, since a drag from the page and one from outside the window arrive
        through different adapters. }}
    <div
      class="sidebar-sections"
      {{dDragAndDropAutoScroll
        types=WEB_LINK_ADOPTION.type
        externalKinds=WEB_LINK_KINDS
      }}
      {{dDragDwell
        types=WEB_LINK_ADOPTION.type
        externalKinds=WEB_LINK_KINDS
        canDwell=this.canDwellForNewSection
        onDwell=this.revealZone
        onDwellEnd=this.hideZone
      }}
    >
      <BlockOutlet @name="sidebar-blocks" />
      <CustomSections
        @collapsable={{@collapsableSections}}
        @enableLinkDrop={{@enableLinkDrop}}
        @toggleNavigationMenu={{@toggleNavigationMenu}}
      />

      {{#if this.zoneRevealed}}
        {{! Where a section created from the drop would go: after the last
            custom section. Pointer-only, like the drag it serves; creating a
            section by keyboard keeps its own path. }}
        <div
          class={{dConcatClass
            "sidebar-link-drop-target"
            (unless this.zoneArmed "is-arming")
            (if this.zoneHovered "is-active")
          }}
          aria-hidden="true"
          {{dDragAndDropExternalTarget
            accepts=WEB_LINK_KINDS
            canDrop=this.canDropLink
            dropEffect="copy"
            indicator=false
            onDragEnter=this.trackZoneHover
            onDragLeave=this.clearZoneHover
            onDrop=this.createSectionFromLink
          }}
          {{! The same drop, for a link the browser started dragging from this
              page rather than from outside the window. }}
          {{dDragAndDropTarget
            adopts=WEB_LINK_ADOPTION
            canDrop=this.canDropLink
            dropEffect="copy"
            indicator=false
            onDragEnter=this.trackZoneHover
            onDragLeave=this.clearZoneHover
            onDrop=this.createSectionFromLink
          }}
        >
          {{dIcon "plus"}}
          <span>{{i18n "sidebar.sections.custom.drop_to_add"}}</span>
        </div>
      {{/if}}

      <CategoriesSection
        @collapsable={{@collapsableSections}}
        @toggleNavigationMenu={{@toggleNavigationMenu}}
      />

      {{#if this.currentUser.display_sidebar_tags}}
        <TagsSection @collapsable={{@collapsableSections}} />
      {{/if}}

      {{#unless @hideApiSections}}
        <ApiSections @collapsable={{@collapsableSections}} />
      {{/unless}}
    </div>
  </template>
}
