import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";
import OnboardingItemEditor from "./onboarding-item-editor.gjs";

const SETTINGS_PATHS = {
  profile: "/my/preferences/profile",
  notifications: "/my/preferences/notifications",
  account: "/my/preferences/account",
};

export default class MemberOnboarding extends Component {
  @service dialog;
  @service toasts;

  @tracked editing = null;
  @tracked saved = null;
  @tracked saving = false;
  @tracked completed = [];

  get configuration() {
    return this.saved ?? this.args.model;
  }

  get items() {
    return this.configuration.items;
  }

  get locked() {
    return this.saving || Boolean(this.editing);
  }

  get previewItems() {
    return this.items.map((item) => ({
      ...item,
      href: item.url.startsWith("/") ? getURL(item.url) : item.url,
      checked: this.completed.includes(item.id),
    }));
  }

  get progress() {
    return i18n("lovelace.onboarding.progress", {
      count: this.items.filter((item) => this.completed.includes(item.id))
        .length,
      total: this.items.length,
    });
  }

  @action
  addItem() {
    this.editing = {
      id: crypto.randomUUID(),
      title: "",
      description: "",
      link_type: "custom",
      url: "",
      button_text: "",
    };
  }

  @action
  editItem(item) {
    this.editing = { ...item };
  }

  @action
  closeEditor() {
    this.editing = null;
  }

  @action
  async saveItem(draft) {
    const item = {
      ...draft,
      url: SETTINGS_PATHS[draft.link_type] ?? draft.url,
    };
    const items = this.items.some((existing) => existing.id === item.id)
      ? this.items.map((existing) =>
          existing.id === item.id ? item : existing
        )
      : [...this.items, item];
    if (await this.#save(items)) {
      this.closeEditor();
    }
  }

  @action
  moveItem(move) {
    const previous = this.configuration;
    this.saved = { ...previous, items: move.proposedToItems };
    this.#save(move.proposedToItems, previous);
  }

  @action
  async removeItem(item) {
    const confirmed = await this.dialog.yesNoConfirm({
      message: i18n("lovelace.onboarding.remove_confirm", {
        title: item.title,
      }),
    });
    if (confirmed) {
      await this.#save(
        this.items.filter((existing) => existing.id !== item.id)
      );
    }
  }

  @action
  togglePreview(id) {
    this.completed = this.completed.includes(id)
      ? this.completed.filter((existing) => existing !== id)
      : [...this.completed, id];
  }

  itemLabel(item) {
    return item.title;
  }

  async #save(items, previous = this.configuration) {
    this.saving = true;
    try {
      this.saved = await ajax("/lovelace/admin/checklist.json", {
        type: "PUT",
        data: JSON.stringify({ items, revision: previous.revision }),
        contentType: "application/json",
      });
      this.toasts.success({
        key: "lovelace-checklist-saved",
        duration: "short",
        data: { message: i18n("lovelace.onboarding.saved") },
      });
      return true;
    } catch (error) {
      this.saved = previous;
      popupAjaxError(error);
      return false;
    } finally {
      this.saving = false;
    }
  }

  <template>
    <div class="lovelace-onboarding" ...attributes>
      <DPageSubheader
        @descriptionLabel={{i18n "lovelace.onboarding.description"}}
        @titleLabel={{i18n "lovelace.onboarding.title"}}
      >
        <:actions as |actions|>
          <actions.Primary
            @action={{this.addItem}}
            @disabled={{this.locked}}
            @label="lovelace.onboarding.add_item"
          />
        </:actions>
      </DPageSubheader>
      <div class="lovelace-onboarding__columns">
        <AdminConfigAreaCard
          class="lovelace-onboarding__items"
          @heading="lovelace.onboarding.items"
        >
          <:content>
            {{#if this.items.length}}
              <DReorderableList
                @disabled={{this.locked}}
                @items={{this.items}}
                @key="id"
                @label={{this.itemLabel}}
                @onMove={{this.moveItem}}
                @onRemove={{this.removeItem}}
              >
                <:row as |item|>
                  <div class="lovelace-onboarding__item">
                    <strong>{{item.title}}</strong>
                    <p>{{item.description}}</p>
                  </div>
                  <DButton
                    class="btn-default"
                    @action={{fn this.editItem item}}
                    @disabled={{this.locked}}
                    @label="edit"
                  />
                </:row>
              </DReorderableList>
            {{else}}
              <p>{{i18n "lovelace.onboarding.empty"}}</p>
            {{/if}}
            {{#if this.editing}}
              <OnboardingItemEditor
                @item={{this.editing}}
                @onCancel={{this.closeEditor}}
                @onSave={{this.saveItem}}
                @saving={{this.saving}}
              />
            {{/if}}
          </:content>
        </AdminConfigAreaCard>
        <AdminConfigAreaCard
          class="lovelace-onboarding__preview"
          @heading="lovelace.onboarding.preview"
        >
          <:content>
            <p class="lovelace-onboarding__progress"><strong
              >{{this.progress}}</strong></p>
            {{#each this.previewItems key="id" as |item|}}
              <div class="lovelace-onboarding__preview-item">
                <p>{{item.description}}</p>
                <label>
                  <Input
                    @checked={{item.checked}}
                    @type="checkbox"
                    {{on "change" (fn this.togglePreview item.id)}}
                  />
                  {{item.title}}
                </label>
                <a
                  class="btn btn-default"
                  href={{item.href}}
                  rel="noopener noreferrer"
                  target="_blank"
                >{{item.button_text}}</a>
              </div>
            {{/each}}
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
