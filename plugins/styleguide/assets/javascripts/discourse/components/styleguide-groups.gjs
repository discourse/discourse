import Component from "@glimmer/component";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { scrollTop } from "discourse/lib/scroll-top";
import StyleguideGroup from "./styleguide-group";
import StyleguideSubnav from "./styleguide-subnav";

/**
 * Splits a long styleguide section into navigable groups, one rendered at a time.
 *
 * The styleguide has no tab, anchor or collapsing primitive, and `StyleguideSection` scrolls to
 * the top on every attrs change, which defeats hash deep-links. So the group lives in a `group`
 * query param instead: real URLs, real history, no change to the shared section component, and
 * only one group's components mounted at a time.
 *
 * @param {Array<{id: string, title: string, description?: string}>} groups - ordered manifest;
 *   the single source of truth for both the subnav and the group order.
 * @param {object} section - the styleguide section, needed to build the `<LinkTo>` route models.
 * @param {string} [active] - the requested group id. This is the `group` query param, which the
 *   section component receives as `@group` and passes in here; the name differs because from
 *   this component's side it is the active selection rather than a URL parameter.
 * @param {string} [ariaLabel] - accessible name for the sub-navigation landmark.
 *
 * Yields a curried `Group` component, so a call site writes `<Group @id="data">…</Group>` and
 * the active-id comparison is supplied for it. `Group` in turn yields a `StyleguideExample`
 * curried to the right heading level.
 */
export default class StyleguideGroups extends Component {
  @service a11y;

  /** The requested group, falling back to the first so an unknown or absent id still renders. */
  get activeId() {
    const groups = this.args.groups ?? [];
    const requested = groups.find((group) => group.id === this.args.active);
    return (requested ?? groups[0])?.id;
  }

  get #activeGroup() {
    return (this.args.groups ?? []).find((group) => group.id === this.activeId);
  }

  // `didUpdate` hands over the element it is installed on, which is what keeps the lookup below
  // scoped to THIS instance's body. A document-wide query would focus the first group on the
  // page, which is the wrong one the moment a section renders two of these.
  @action
  handleGroupChange(element) {
    // The pill that was clicked survives the swap, so focus is usually fine. It is not fine when
    // the group changed via Back/Forward while focus sat inside the outgoing group's body: that
    // node unmounts and focus falls to `<body>`. Only then is it ours to restore.
    if (document.activeElement === document.body) {
      element.querySelector(".styleguide-group")?.focus();
    }

    // Nothing else signals to a screen reader that the page's content was replaced.
    if (this.#activeGroup?.title) {
      this.a11y.announce(this.#activeGroup.title, "polite");
    }

    scrollTop();
  }

  <template>
    <StyleguideSubnav
      @groups={{@groups}}
      @section={{@section}}
      @activeId={{this.activeId}}
      @ariaLabel={{@ariaLabel}}
    />

    <div
      class="styleguide-groups__body"
      {{didUpdate this.handleGroupChange this.activeId}}
    >
      {{yield
        (component StyleguideGroup activeId=this.activeId groups=@groups)
      }}
    </div>
  </template>
}
