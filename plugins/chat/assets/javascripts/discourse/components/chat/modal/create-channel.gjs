import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isBlank, isPresent } from "@ember/utils";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import I18n, { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";
import DTooltip from "float-kit/components/d-tooltip";

const DEFAULT_HINT = htmlSafe(
  i18n("chat.create_channel.choose_category.default_hint", {
    link: "/categories",
    category: "category",
  })
);

export default class ChatModalCreateChannel extends Component {
  @service chat;
  @service dialog;
  @service chatChannelsManager;
  @service chatApi;
  @service router;
  @service currentUser;
  @service siteSettings;
  @service site;

  @tracked flash;
  @tracked name;
  @tracked category;
  @tracked categoryId;
  @tracked autoGeneratedSlug = "";
  @tracked categoryPermissionsHint;
  @tracked autoJoinWarning = "";
  @tracked loadingPermissionHint = false;

  #generateSlugHandler = null;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#generateSlugHandler);
  }

  get autoJoinAvailable() {
    return this.siteSettings.max_chat_auto_joined_users > 0;
  }

  get categorySelected() {
    return isPresent(this.category);
  }

  get createDisabled() {
    return !this.categorySelected || isBlank(this.name);
  }

  get categoryName() {
    return this.categorySelected ? escapeExpression(this.category?.name) : null;
  }

  @action
  onShow() {
    this.categoryPermissionsHint = DEFAULT_HINT;
  }

  @action
  onCategoryChange(categoryId) {
    const category = categoryId ? Category.findById(categoryId) : null;
    this.#updatePermissionsHint(category);

    const name = this.name || category?.name || "";
    this.categoryId = categoryId;
    this.category = category;
    this.name = name;
    this.#debouncedGenerateSlug(name);
  }

  @action
  onNameChange(name) {
    this.#debouncedGenerateSlug(name);
  }

  @action
  onSave(event) {
    event.preventDefault();

    if (this.createDisabled) {
      return;
    }

    const formData = new FormData(event.currentTarget);
    const data = Object.fromEntries(formData.entries());
    data.auto_join_users = data.auto_join_users === "on";
    data.slug ??= this.autoGeneratedSlug;
    data.threading_enabled = data.threading_enabled === "on";

    if (data.auto_join_users) {
      this.dialog.yesNoConfirm({
        message: this.autoJoinWarning,
        didConfirm: () => this.#createChannel(data),
      });
    } else {
      this.#createChannel(data);
    }
  }

  async #createChannel(data) {
    try {
      const channel = await this.chatApi.createChannel(data);

      this.args.closeModal();
      this.chatChannelsManager.follow(channel);
      this.router.transitionTo("chat.channel", ...channel.routeModels);
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  #buildCategorySlug(category) {
    const parent = category.parentCategory;

    if (parent) {
      return `${this.#buildCategorySlug(parent)}/${category.slug}`;
    } else {
      return category.slug;
    }
  }

  #updateAutoJoinConfirmWarning(category, catPermissions) {
    const allowedGroups = catPermissions.allowed_groups;
    let warning;

    if (catPermissions.private) {
      switch (allowedGroups.length) {
        case 1:
          warning = i18n(
            "chat.create_channel.auto_join_users.warning_1_group",
            {
              count: catPermissions.members_count,
              group: escapeExpression(allowedGroups[0]),
            }
          );
          break;
        case 2:
          warning = i18n(
            "chat.create_channel.auto_join_users.warning_2_groups",
            {
              count: catPermissions.members_count,
              group1: escapeExpression(allowedGroups[0]),
              group2: escapeExpression(allowedGroups[1]),
            }
          );
          break;
        default:
          warning = I18n.messageFormat(
            "chat.create_channel.auto_join_users.warning_multiple_groups_MF",
            {
              groupCount: allowedGroups.length - 1,
              userCount: catPermissions.members_count,
              groupName: escapeExpression(allowedGroups[0]),
            }
          );
          break;
      }
    } else {
      warning = i18n(
        "chat.create_channel.auto_join_users.public_category_warning",
        {
          category: escapeExpression(category.name),
        }
      );
    }

    this.autoJoinWarning = warning;
  }

  #updatePermissionsHint(category) {
    if (category) {
      const fullSlug = this.#buildCategorySlug(category);

      this.loadingPermissionHint = true;

      return this.chatApi
        .categoryPermissions(category.id)
        .then((catPermissions) => {
          this.#updateAutoJoinConfirmWarning(category, catPermissions);
          const allowedGroups = catPermissions.allowed_groups;
          const settingLink = `/c/${escapeExpression(fullSlug)}/edit/security`;
          let hint;

          switch (allowedGroups.length) {
            case 1:
              hint = i18n("chat.create_channel.choose_category.hint_1_group", {
                settingLink,
                group: escapeExpression(allowedGroups[0]),
              });
              break;
            case 2:
              hint = i18n("chat.create_channel.choose_category.hint_2_groups", {
                settingLink,
                group1: escapeExpression(allowedGroups[0]),
                group2: escapeExpression(allowedGroups[1]),
              });
              break;
            default:
              hint = i18n(
                "chat.create_channel.choose_category.hint_multiple_groups",
                {
                  settingLink,
                  group: escapeExpression(allowedGroups[0]),
                  count: allowedGroups.length - 1,
                }
              );
              break;
          }

          this.categoryPermissionsHint = htmlSafe(hint);
        })
        .finally(() => {
          this.loadingPermissionHint = false;
        });
    } else {
      this.categoryPermissionsHint = DEFAULT_HINT;
      this.autoJoinWarning = "";
    }
  }

  // intentionally not showing AJAX error for this, we will autogenerate
  // the slug server-side if they leave it blank
  #generateSlug(name) {
    return ajax("/slugs.json", { type: "POST", data: { name } }).then(
      (response) => {
        this.autoGeneratedSlug = response.slug;
      }
    );
  }

  #debouncedGenerateSlug(name) {
    cancel(this.#generateSlugHandler);
    this.autoGeneratedSlug = "";

    if (!name) {
      return;
    }

    this.#generateSlugHandler = discourseDebounce(
      this,
      this.#generateSlug,
      name,
      300
    );
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="chat-modal-create-channel"
      @inline={{@inline}}
      @title={{i18n "chat.create_channel.title"}}
      @flash={{this.flash}}
      @tagName="form"
      {{on "submit" this.onSave}}
    >
      <:body>
        <div class="chat-modal-create-channel__control -name">
          <label for="name" class="chat-modal-create-channel__label">
            {{i18n "chat.create_channel.name"}}
          </label>
          <Input
            name="name"
            class="chat-modal-create-channel__input"
            @type="text"
            @value={{this.name}}
            {{on "input" (withEventValue this.onNameChange)}}
          />
        </div>

        <div class="chat-modal-create-channel__control -slug">
          <label for="slug" class="chat-modal-create-channel__label">
            {{i18n "chat.create_channel.slug"}}&nbsp;
            <span>
              {{icon "circle-info"}}
              <DTooltip>
                {{i18n "chat.channel_edit_name_slug_modal.slug_description"}}
              </DTooltip>
            </span>
          </label>
          <Input
            name="slug"
            class="chat-modal-create-channel__input"
            @type="text"
            @value={{this.slug}}
            placeholder={{this.autoGeneratedSlug}}
          />
        </div>

        <div class="chat-modal-create-channel__control -description">
          <label for="description" class="chat-modal-create-channel__label">
            {{i18n "chat.create_channel.description"}}
          </label>
          <Input
            name="description"
            class="chat-modal-create-channel__input"
            @type="textarea"
            @value={{this.description}}
          />
        </div>

        <div class="chat-modal-create-channel__control">
          <label class="chat-modal-create-channel__label">
            {{i18n "chat.create_channel.choose_category.label"}}
          </label>
          <CategoryChooser
            @value={{this.categoryId}}
            @onChange={{this.onCategoryChange}}
            @options={{hash
              formName="chatable_id"
              none="chat.create_channel.choose_category.none"
            }}
          />

          {{#if this.categoryPermissionsHint}}
            <div
              class={{concatClass
                "chat-modal-create-channel__hint"
                (if this.loadingPermissionHint "loading-permissions")
              }}
            >
              {{this.categoryPermissionsHint}}
            </div>
          {{/if}}
        </div>

        {{#if this.autoJoinAvailable}}
          <div class="chat-modal-create-channel__control -auto-join">
            <label class="chat-modal-create-channel__label">
              <Input
                name="auto_join_users"
                @type="checkbox"
                @checked={{this.autoJoinUsers}}
              />
              <div class="auto-join-channel">
                <span class="chat-modal-create-channel__label-title">
                  {{i18n "chat.settings.auto_join_users_label"}}
                </span>
                <p class="chat-modal-create-channel__label-description">
                  {{#if this.categoryName}}
                    {{i18n
                      "chat.settings.auto_join_users_info"
                      category=this.categoryName
                    }}
                  {{else}}
                    {{i18n "chat.settings.auto_join_users_info_no_category"}}
                  {{/if}}
                </p>
              </div>
            </label>
          </div>
        {{/if}}

        <div class="chat-modal-create-channel__control -threading-toggle">
          <label class="chat-modal-create-channel__label">
            <Input
              name="threading_enabled"
              @type="checkbox"
              @checked={{this.threadingEnabled}}
            />
            <div class="threading-channel">
              <span class="chat-modal-create-channel__label-title">
                {{i18n "chat.create_channel.threading.label"}}
              </span>
              <p class="chat-modal-create-channel__label-description">
                {{i18n "chat.settings.channel_threading_description"}}
              </p>
            </div>
          </label>
        </div>
      </:body>
      <:footer>
        <button
          class="btn btn-primary create"
          disabled={{this.createDisabled}}
          type="submit"
        >
          {{i18n "chat.create_channel.create"}}
        </button>
      </:footer>
    </DModal>
  </template>
}
