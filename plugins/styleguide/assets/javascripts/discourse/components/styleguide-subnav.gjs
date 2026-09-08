import { array, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { eq } from "discourse/truth-helpers";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";

/**
 * Sub-navigation for a styleguide section that is split into groups.
 *
 * These are real navigations — each pill is a distinct URL (`?group=…`) with history and
 * open-in-new-tab — so the markup is links inside a `<nav>`, not `role="tablist"`. Giving them
 * tab roles would override the link role, lose the "this navigates" expectation, and oblige a
 * roving tabindex that fights `<LinkTo>`'s natural tab order.
 *
 * `DHorizontalOverflowNav` renders the `<ul class="nav-pills">` itself, so this yields bare
 * `<li>` elements into it; wrapping them in another `<ul>` would break both `.nav-pills > li > a`
 * styling and the component's own drag-scroll lookup.
 *
 * Active state is computed from `@activeId` rather than left to `<LinkTo>`: the default group
 * carries no `?group=` in the URL, so Ember would never mark it active. The class goes on the
 * `<a>`, which is what both `.nav-pills` styling and the overflow nav's auto-scroll key off,
 * and `aria-current` carries the state non-visually — `<LinkTo>` emits none of its own.
 */
const StyleguideSubnav = <template>
  <div class="styleguide-subnav">
    <DHorizontalOverflowNav @ariaLabel={{@ariaLabel}}>
      {{#each @groups key="id" as |group|}}
        <li>
          <LinkTo
            aria-current={{if (eq group.id @activeId) "page"}}
            class={{if (eq group.id @activeId) "active"}}
            data-test-styleguide-subnav-link={{group.id}}
            @models={{array @section.category @section.id}}
            @query={{hash group=group.id}}
            @route="styleguide.show"
          >
            {{group.title}}
          </LinkTo>
        </li>
      {{/each}}
    </DHorizontalOverflowNav>
  </div>
</template>;

export default StyleguideSubnav;
