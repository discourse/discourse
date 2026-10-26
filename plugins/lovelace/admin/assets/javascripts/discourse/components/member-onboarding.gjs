import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";
import MemberChecklist from "discourse/plugins/lovelace/discourse/components/member-checklist";
import OnboardingItemContent from "./onboarding-item-content.gjs";
import OnboardingItemEditor from "./onboarding-item-editor.gjs";

const SETTINGS_PATHS = {
  profile: "/my/preferences/profile",
  notifications: "/my/preferences/notifications",
  account: "/my/preferences/account",
};

export default class MemberOnboarding extends Component {
  @service dialog;
  @service modal;
  @service toasts;

  @tracked editing = null;
  @tracked saved = null;
  @tracked saving = false;
  @tracked completed = [];
  @tracked _previewDismissed = false;
  @tracked _previewMinimized = false;

  get bank() {
    return this.configuration.bank;
  }

  get configuration() {
    return this.saved ?? this.args.model;
  }

  get items() {
    return this.configuration.items;
  }

  get locked() {
    return this.saving || Boolean(this.editing);
  }

  get previewChecklist() {
    return {
      items: this.items,
      completed_ids: this.completed.filter((id) =>
        this.items.some((item) => item.id === id)
      ),
      dismissed: this._previewDismissed,
      minimized: this._previewMinimized,
    };
  }

  @action
  addItem() {
    this.#openEditor(
      {
        id: crypto.randomUUID(),
        title: "",
        description: "",
        link_type: "custom",
        url: "",
        button_text: "",
      },
      "lovelace.onboarding.add_item"
    );
  }

  @action
  async addSuggestion(item) {
    if (await this.#save([...this.items, item])) {
      this.completed = this.completed.filter((id) => id !== item.id);
    }
  }

  @action
  editItem(item) {
    this.#openEditor({ ...item }, "lovelace.onboarding.edit_item");
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
    return this.#save(items);
  }

  @action
  moveItem(move) {
    const previous = this.configuration;
    this.saved = { ...previous, items: move.proposedToItems };
    this.#save(move.proposedToItems, previous);
  }

  @action
  async removeItem(item) {
    const confirmed =
      this.configuration.unmodified_seed_ids?.includes(item.id) ||
      (await this.dialog.yesNoConfirm({
        message: i18n("lovelace.onboarding.remove_confirm", {
          title: item.title,
        }),
      }));
    if (confirmed) {
      await this.#save(
        this.items.filter((existing) => existing.id !== item.id)
      );
    }
  }

  @action
  updatePreview(checklist) {
    this.completed = checklist.completed_ids;
    this._previewDismissed = checklist.dismissed;
    this._previewMinimized = checklist.minimized;
  }

  @action
  resetPreview() {
    this.completed = [];
    this._previewDismissed = false;
    this._previewMinimized = false;
  }

  itemLabel(item) {
    return item.title;
  }

  async #openEditor(item, title) {
    this.editing = item;
    await this.modal.show(OnboardingItemEditor, {
      model: { item, title, onSave: this.saveItem },
    });
    this.editing = null;
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
        <div class="lovelace-onboarding__configuration">
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
                  @rowClass="lovelace-onboarding__row"
                >
                  <:row as |item|>
                    <OnboardingItemContent @item={{item}} />
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
            </:content>
          </AdminConfigAreaCard>
          <AdminConfigAreaCard
            class="lovelace-onboarding__bank"
            @heading="lovelace.bank"
          >
            <:content>
              <p>{{i18n "lovelace.bank_description"}}</p>
              <ul class="lovelace-onboarding__list">
                {{#each this.bank key="id" as |item|}}
                  <li
                    class="lovelace-onboarding__row lovelace-onboarding__suggestion"
                  >
                    <OnboardingItemContent @item={{item}} />
                    <DButton
                      class="btn-default"
                      @action={{fn this.addSuggestion item}}
                      @disabled={{this.locked}}
                      @label="lovelace.add"
                    />
                  </li>
                {{else}}
                  <li>{{i18n "lovelace.bank_empty"}}</li>
                {{/each}}
              </ul>
            </:content>
          </AdminConfigAreaCard>
        </div>
        <AdminConfigAreaCard
          class="lovelace-onboarding__preview"
          @heading="lovelace.onboarding.preview"
        >
          <:content>
            <DButton
              class="btn-default lovelace-onboarding__reset-preview"
              @action={{this.resetPreview}}
              @label="lovelace.onboarding.reset_preview"
            />
            <MemberChecklist
              @onPreviewChange={{this.updatePreview}}
              @previewChecklist={{this.previewChecklist}}
            />
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
