import type { TOC } from "@ember/component/template-only";
import decorateUsernameSelector from "discourse/helpers/decorate-username-selector";
import { formatUsername } from "discourse/lib/utilities";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import {
  disabledReason,
  GroupOption,
  recordName,
} from "discourse/ui-kit/select/recipes/groups/-internals/group-renderers";
import {
  renderSelectText,
  type SelectConfig,
  type SelectRecord,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The kinds of value a user picker holds; `unknown` is a name nothing resolved. */
export type UserPickType = "user" | "group" | "email" | "unknown";

/** The translations a chip's type words default to when it's drawn without the select's options. */
const TYPE_TEXT_KEYS: Readonly<Record<string, string>> = {
  groupType: "select_user.group_type",
  emailType: "select_user.email_type",
  unknownType: "select_user.unknown_type",
};

/** A chip's type word, from the select's options when the chip has them. */
function typeText(config: SelectConfig | undefined, key: string) {
  return config ? renderSelectText(config, key) : i18n(TYPE_TEXT_KEYS[key]!);
}

/** Narrows an item's type at the rendering boundary. */
function isType(item: SelectRecord, type: UserPickType): boolean {
  return item.type === type;
}

/** Narrows optional action icons at the rendering boundary. */
function actionIcon(item: SelectRecord): string | undefined {
  return typeof item.icon === "string" ? item.icon : undefined;
}

/** The status emoji drawn after a user, when the picker shows statuses. */
function statusEmoji(item: SelectRecord): string | undefined {
  return typeof item.statusEmoji === "string" ? item.statusEmoji : undefined;
}

/** A user's full name, when the site sent one. */
function fullName(item: SelectRecord): string | undefined {
  return typeof item.fullName === "string" && item.fullName
    ? item.fullName
    : undefined;
}

/** A held user's avatar and username. */
const UserIdentity: TOC<{ Args: { record: SelectRecord } }> = <template>
  {{dAvatar @record imageSize="tiny"}}
  <span class="d-user-option__username">
    {{~formatUsername (recordName @record)~}}
  </span>
</template>;

/**
 * Default option content: a user, a group or an address. Other rows, such as a call site's
 * special rows, draw their name.
 */
export const UserOption: TOC<{
  Args: {
    /** The row, whose `type` says what it is. */
    record: SelectRecord;
  };
}> = <template>
  {{#if @record.onSelect}}
    {{#if (actionIcon @record)}}{{dIcon (actionIcon @record)}}{{/if}}
    {{recordName @record}}
  {{else if (isType @record "user")}}
    <span class="d-user-option">
      {{dAvatar @record imageSize="tiny"}}
      {{! One line of text, so the smaller name sits on the username's baseline. }}
      <span class="d-user-option__label">
        <span class="d-user-option__username">
          {{~formatUsername (recordName @record)~}}
        </span>
        {{! Keep the space before the name: without it screen readers run the two words together. }}
        {{#if (fullName @record)~}}
          <span class="d-user-option__name">{{fullName @record}}</span>
        {{~/if~}}
      </span>
      {{#if (statusEmoji @record)}}
        <span class="d-user-option__status">
          {{~dEmoji (statusEmoji @record) alt="" skipTitle=true~}}
        </span>
      {{/if}}
      {{#if (disabledReason @record)}}
        <span class="d-user-option__reason">
          {{~dIcon "ban"~}}
          {{~disabledReason @record~}}
        </span>
      {{/if}}
      <span aria-hidden="true" class="d-user-option__decorations">
        {{~decorateUsernameSelector (recordName @record)~}}
      </span>
    </span>
  {{else if (isType @record "group")}}
    <GroupOption @icon={{true}} @record={{@record}} />
  {{else if (isType @record "email")}}
    <span class="d-email-option">
      {{dIcon "envelope"}}
      <span class="d-email-option__address">{{recordName @record}}</span>
    </span>
  {{else}}
    {{recordName @record}}
  {{/if}}
</template>;

/**
 * Default held-value content. A group, an address or a name nobody has also gets a hidden type
 * word, since its icon is hidden from screen readers.
 */
export const UserSelection: TOC<{
  Args: {
    /** The held value's item. */
    record: SelectRecord;
    /** The select's resolved config, which carries its texts. */
    config?: SelectConfig;
  };
}> = <template>
  {{#if (isType @record "user")}}
    <span class="d-user-option --selection">
      <UserIdentity @record={{@record}} />
    </span>
  {{else if (isType @record "group")}}
    <span class="d-group-option --selection">
      {{dIcon "users"}}
      <span class="d-group-option__name">{{recordName @record}}</span>
      <span class="sr-only">{{typeText @config "groupType"}}</span>
    </span>
  {{else if (isType @record "email")}}
    <span class="d-email-option --selection">
      {{dIcon "envelope"}}
      <span class="d-email-option__address">{{recordName @record}}</span>
      <span class="sr-only">{{typeText @config "emailType"}}</span>
    </span>
  {{else if (isType @record "unknown")}}
    <span class="d-unknown-option --selection">
      {{dIcon "triangle-exclamation"}}
      <span class="d-unknown-option__name">{{recordName @record}}</span>
      <span class="sr-only">{{typeText @config "unknownType"}}</span>
    </span>
  {{else}}
    {{recordName @record}}
  {{/if}}
</template>;
