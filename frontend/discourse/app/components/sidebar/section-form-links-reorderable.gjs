import Component from "@glimmer/component";
import SectionFormLinkReorderable from "discourse/components/sidebar/section-form-link-reorderable";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { bind } from "discourse/lib/decorators";
import { eq, has } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";
import { i18n } from "discourse-i18n";

/**
 * The section form's links region behind `enable_new_reordering_controls`, over
 * the shared reorderable list. The two lists are grouped so a link can move
 * between the primary set and the more menu.
 *
 * The arrays arrive by reference and are mutated in place, which is what the
 * form's own tracking already relies on.
 *
 * TODO (ui-kit-reorderable-list-cleanup) rename this over
 * `section-form-links.gjs` and drop the branch in the section form.
 */
export default class SidebarSectionFormLinksReorderable extends Component {
  linkName = (link) => link.name;

  /**
   * Applies a committed move onto the backing arrays, which hold links awaiting
   * deletion as well as visible ones.
   *
   * @param {Object} move - The normalized move from the list.
   */
  @bind
  handleMove(move) {
    const arrays = {
      primary: this.args.links,
      secondary: this.args.secondaryLinks,
    };
    const source = arrays[move.fromList];
    const destination = arrays[move.toList];

    if (move.fromList !== move.toList) {
      removeValueFromArray(source, move.item);
      move.item.segment = move.toList;
      // Anchored on the visible link that follows the landing slot, so links
      // awaiting deletion keep their positions in the stored array.
      const following = move.proposedToItems[move.toIndex + 1];
      const at = following
        ? destination.indexOf(following)
        : destination.length;
      destination.splice(at, 0, move.item);
      return;
    }

    const proposed = [...move.proposedToItems];
    const next = destination.map((link) =>
      link._destroy ? link : proposed.shift()
    );
    destination.splice(0, destination.length, ...next);
  }

  <template>
    <DReorderableListGroup @onMove={{this.handleMove}} as |group|>
      <DReorderableList
        @group={{group}}
        @listId="primary"
        @listLabel={{i18n "sidebar.sections.custom.links.title"}}
        @items={{@activeLinks}}
        @key="objectId"
        @label={{this.linkName}}
        @controls="manual"
        @tag="div"
        @role="table"
        @itemTag="div"
        @itemRole="row"
        @rowClass="sidebar-section-form-link row-wrapper"
        aria-labelledby="section-links-label"
        aria-rowcount={{@activeLinks.length}}
        class="sidebar-section-form__links-wrapper"
      >
        <:header>
          {{! The list element around this block carries the table role
                through its role argument, which the static rule cannot
                see from here. }}
          {{! eslint-disable-next-line ember/template-require-context-role }}
          <div class="row-wrapper header" role="row">
            <div
              class="input-group link-icon"
              role="columnheader"
              aria-sort="none"
            >
              {{! eslint-disable-next-line ember/template-no-nested-interactive }}
              <label>{{i18n "sidebar.sections.custom.links.icon.label"}}</label>
            </div>

            <div
              class="input-group link-name"
              role="columnheader"
              aria-sort="none"
            >
              {{! eslint-disable-next-line ember/template-no-nested-interactive }}
              <label>{{i18n "sidebar.sections.custom.links.name.label"}}</label>
            </div>

            <div
              class="input-group link-url"
              role="columnheader"
              aria-sort="none"
            >
              {{! eslint-disable-next-line ember/template-no-nested-interactive }}
              <label>{{i18n
                  "sidebar.sections.custom.links.value.label"
                }}</label>
            </div>
          </div>
        </:header>
        <:row as |link controls|>
          <SectionFormLinkReorderable
            @controls={{controls}}
            @link={{link}}
            @focusNameInput={{eq link.objectId @initialFocusLinkObjectId}}
            @duplicateValue={{has @duplicateLinkObjectIds link.objectId}}
            @deleteLink={{@deleteLink}}
          />
        </:row>
      </DReorderableList>
      <DButton
        @action={{@addLink}}
        @title="sidebar.sections.custom.links.add"
        @icon="plus"
        @label="sidebar.sections.custom.links.add"
        @ariaLabel="sidebar.sections.custom.links.add"
        class="btn-flat btn-text add-link"
      />

      {{#if @sectionType}}
        <hr />
        <h3 id="section-secondary-links-label">{{i18n
            "sidebar.sections.custom.more_menu"
          }}</h3>
        {{! The rows resolve their columns through the wrapper's grid, so
          a list rendered without one would collapse. }}
        <DReorderableList
          @group={{group}}
          @listId="secondary"
          @listLabel={{i18n "sidebar.sections.custom.more_menu"}}
          @items={{@activeSecondaryLinks}}
          @key="objectId"
          @label={{this.linkName}}
          @controls="manual"
          @tag="div"
          @role="table"
          @itemTag="div"
          @itemRole="row"
          @rowClass="sidebar-section-form-link row-wrapper"
          aria-labelledby="section-secondary-links-label"
          aria-rowcount={{@activeSecondaryLinks.length}}
          class="sidebar-section-form__links-wrapper --secondary"
        >
          <:row as |link controls|>
            <SectionFormLinkReorderable
              @controls={{controls}}
              @link={{link}}
              @duplicateValue={{has @duplicateLinkObjectIds link.objectId}}
              @deleteLink={{@deleteLink}}
            />
          </:row>
        </DReorderableList>
        <DButton
          @action={{@addSecondaryLink}}
          @title="sidebar.sections.custom.links.add"
          @icon="plus"
          @label="sidebar.sections.custom.links.add"
          @ariaLabel="sidebar.sections.custom.links.add"
          class="btn-flat btn-text add-link"
        />
      {{/if}}
    </DReorderableListGroup>
  </template>
}
