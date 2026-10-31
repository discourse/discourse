import type { TOC } from "@ember/component/template-only";
import decorateUsernameSelector from "discourse/helpers/decorate-username-selector";
import { formatUsername } from "discourse/lib/utilities";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import {
  GroupOption,
  itemName,
} from "discourse/ui-kit/select/recipes/groups/-internals/group-renderers";
import {
  renderSelectText,
  type SelectItem,
  type SelectResolvedOptions,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The kinds of value a user picker holds. */
export type UserPickType = "user" | "group" | "email";

/** The translations a chip's type words default to when it's drawn without the select's options. */
const TYPE_TEXT_KEYS: Readonly<Record<string, string>> = {
  groupType: "select_user.group_type",
  emailType: "select_user.email_type",
};

/** A chip's type word, from the select's options when the chip has them. */
function typeText(options: SelectResolvedOptions | undefined, key: string) {
  return options ? renderSelectText(options, key) : i18n(TYPE_TEXT_KEYS[key]!);
}

/** Narrows an item's type at the rendering boundary. */
function isType(item: SelectItem, type: UserPickType): boolean {
  return item.type === type;
}

/** Narrows optional action icons at the rendering boundary. */
function actionIcon(item: SelectItem): string | undefined {
  return typeof item.icon === "string" ? item.icon : undefined;
}

/** The status emoji drawn after a user, when the picker shows statuses. */
function statusEmoji(item: SelectItem): string | undefined {
  return typeof item.statusEmoji === "string" ? item.statusEmoji : undefined;
}

/** A user's full name, when the site sent one. */
function fullName(item: SelectItem): string | undefined {
  return typeof item.fullName === "string" && item.fullName
    ? item.fullName
    : undefined;
}

/** A user row's avatar and username, shared by rows and chips. */
const UserIdentity: TOC<{ Args: { item: SelectItem } }> = <template>
  {{dAvatar @item imageSize="tiny"}}
  <span class="d-user-option__username">
    {{~formatUsername (itemName @item)~}}
  </span>
</template>;

/**
 * Default option content: a user, a group or an address. Other rows, such as a call site's
 * special rows, draw their name.
 */
export const UserOption: TOC<{
  Args: {
    /** The row, whose `type` says what it is. */
    item: SelectItem;
  };
}> = <template>
  {{#if @item.onSelect}}
    {{#if (actionIcon @item)}}{{dIcon (actionIcon @item)}}{{/if}}
    {{itemName @item}}
  {{else if (isType @item "user")}}
    <span class="d-user-option">
      <UserIdentity @item={{@item}} />
      {{#if (fullName @item)}}
        <span class="d-user-option__name">{{fullName @item}}</span>
      {{/if}}
      {{#if (statusEmoji @item)}}
        <span class="d-user-option__status">
          {{~dEmoji (statusEmoji @item) alt="" skipTitle=true~}}
        </span>
      {{/if}}
      <span aria-hidden="true" class="d-user-option__decorations">
        {{~decorateUsernameSelector (itemName @item)~}}
      </span>
    </span>
  {{else if (isType @item "group")}}
    <GroupOption @icon={{true}} @item={{@item}} />
  {{else if (isType @item "email")}}
    <span class="d-email-option">
      {{dIcon "envelope"}}
      <span class="d-email-option__address">{{itemName @item}}</span>
    </span>
  {{else}}
    {{itemName @item}}
  {{/if}}
</template>;

/**
 * Default held-value content. A group or an address also gets a hidden type word, since its
 * icon is hidden from screen readers.
 */
export const UserSelection: TOC<{
  Args: {
    /** The held value's item. */
    item: SelectItem;
    /** The select's resolved options, which carry its texts. */
    options?: SelectResolvedOptions;
  };
}> = <template>
  {{#if (isType @item "user")}}
    <span class="d-user-option --selection">
      <UserIdentity @item={{@item}} />
    </span>
  {{else if (isType @item "group")}}
    <span class="d-group-option --selection">
      {{dIcon "users"}}
      <span class="d-group-option__name">{{itemName @item}}</span>
      <span class="sr-only">{{typeText @options "groupType"}}</span>
    </span>
  {{else if (isType @item "email")}}
    <span class="d-email-option --selection">
      {{dIcon "envelope"}}
      <span class="d-email-option__address">{{itemName @item}}</span>
      <span class="sr-only">{{typeText @options "emailType"}}</span>
    </span>
  {{else}}
    {{itemName @item}}
  {{/if}}
</template>;
