import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const OPTIONS = [
  { id: "listed", icon: "far-eye" },
  { id: "unlisted", icon: "list" },
  { id: "hidden", icon: "far-eye-slash" },
];

export default class VisibilityMenu extends Component {
  get options() {
    return OPTIONS.map((option) => ({
      ...option,
      title: i18n(`post.revisions.visibility.${option.id}.title`),
      description: i18n(`post.revisions.visibility.${option.id}.description`),
    }));
  }

  get current() {
    return this.options.find((option) => option.id === this.args.visibility);
  }

  get otherOptions() {
    return this.options.filter((option) => option.id !== this.args.visibility);
  }

  @action
  async select(close, id) {
    await close();
    this.args.onChange(id);
  }

  @action
  async delete(close) {
    await close();
    this.args.onPermanentlyDelete();
  }

  <template>
    {{! Inline, or the menu renders behind the modal it opens from. }}
    <DMenu
      @disabled={{@disabled}}
      @icon={{this.current.icon}}
      @identifier="revision-visibility"
      @inline={{true}}
      @label={{this.current.title}}
      @modalForMobile={{true}}
      @triggerClass="btn-default revision-visibility__trigger"
    >
      <:trigger>
        {{dIcon "angle-down" class="revision-visibility__caret"}}
      </:trigger>
      <:content as |menu|>
        <DDropdownMenu as |dropdown|>
          {{#each this.otherOptions as |option|}}
            <dropdown.item>
              <DButton
                class="revision-visibility-btn --with-description"
                data-revision-visibility={{option.id}}
                @action={{fn this.select menu.close option.id}}
              >
                <div class="revision-visibility-btn__icons">
                  {{dIcon option.icon}}
                </div>
                <div class="revision-visibility-btn__texts">
                  <span class="revision-visibility-btn__label">
                    {{option.title}}
                  </span>
                  <span class="revision-visibility-btn__description">
                    {{option.description}}
                  </span>
                </div>
              </DButton>
            </dropdown.item>
          {{/each}}
          {{#if @canPermanentlyDelete}}
            <dropdown.divider />
            <dropdown.item>
              <DButton
                class="btn-transparent btn-danger destroy-revision"
                @action={{fn this.delete menu.close}}
                @icon="trash-can"
                @label="post.revisions.controls.destroy"
              />
            </dropdown.item>
          {{/if}}
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
