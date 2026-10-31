import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import { findUsersByUsernames, searchUsers } from "discourse/lib/user-search";
import { emailValid } from "discourse/lib/utilities";
import type User from "discourse/models/user";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import { groupFields } from "discourse/ui-kit/select/recipes/groups/-internals/group-renderers";
import {
  UserOption,
  type UserPickType,
  UserSelection,
} from "discourse/ui-kit/select/recipes/users/-internals/user-renderers";
import {
  type SelectUserTextKey,
  USER_TEXTS,
  userPickerName,
} from "discourse/ui-kit/select/recipes/users/-internals/user-texts";
import type {
  SelectItem,
  SelectItemId,
  SelectLoadOptions,
  SelectResolvedOptions,
  SelectTexts,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** Which groups the picker offers, as the server's include flags. */
type UserPickerGroups = "visible" | "mentionable" | "messageable";

/** A search or lookup row, as `lib/user-search` returns it. */
type UserSearchRow = {
  type: UserPickType;
  value: string;
  username?: string;
  name?: string;
  full_name?: string | null;
  avatar_template?: string;
  status?: { emoji?: string; description?: string } | null;
};

/** A held or picked value's item: the value, its label and what it is. */
export type UserPickItem = SelectItem & {
  id: string;
  name: string;
  /** Absent for a name nothing resolved and for a call site's special rows. */
  type?: UserPickType;
};

/** The user picker's arguments and the engine's forwarded presentation contract. */
interface DSelectUserSignature {
  Args: Pick<
    DSelectSignature["Args"],
    | "ariaLabelledBy"
    | "clearable"
    | "describedBy"
    | "disabled"
    | "icon"
    | "id"
    | "identifier"
    | "instanceContext"
    | "invalid"
    | "legacyKind"
    | "maximum"
    | "maxVisibleChips"
    | "onClose"
    | "specialItems"
    | "variant"
  > & {
    /** Held usernames, group names or addresses. */
    value?: string | readonly string[] | null;
    /** Holds several values; defaults to one, as DSelect does. */
    multiple?: boolean;
    /** Offers groups too: the visible ones, those the user can mention, or those they can message. */
    includeGroups?: UserPickerGroups;
    /** Offers a valid typed address as a row. */
    emails?: boolean;
    /** Usernames and group names never offered, in any case. */
    exclude?: readonly string[];
    /** Leaves the current user out of the results. */
    excludeCurrentUser?: boolean;
    /** Includes staged users in searches and lookups. */
    includeStaged?: boolean;
    /** Scopes the search to a topic's users, listed before anything is typed. */
    topicId?: number;
    /** Scopes the search to a category's users, listed before anything is typed. */
    categoryId?: number;
    /**
     * Extra search params; camelCase keys are sent snake_cased and unset ones aren't sent.
     * Customizations override it as the `searchOptions` option.
     */
    searchOptions?: Record<string, unknown>;
    /** Shows each user's status in the rows. */
    showStatus?: boolean;
    /** The picker's texts, over its defaults: the engine's, `groupType` and `emailType`. */
    texts?: SelectTexts<SelectUserTextKey>;
    /**
     * Receives the held values and their items, whose `type` tells a user from a group
     * or an address: arrays when multiple, otherwise one value or `null`.
     */
    onChange?: (
      value: string[] | string | null,
      items: UserPickItem[] | UserPickItem | null
    ) => void;
  };
  Element: HTMLElement;
  Blocks: Pick<DSelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/**
 * Picks users, and groups or addresses when asked, from the server's user search. Held names
 * are looked up together, and keep the spelling they were given.
 */
export default class DSelectUser extends Component<DSelectUserSignature> {
  @service declare currentUser: User | null;

  /** The picker's texts, named after what it offers and whether it holds more than one. */
  kindTexts: SelectTexts = {
    ...USER_TEXTS,
    ariaLabel: (_values, context) =>
      userPickerName({
        plural: context.multiple && this.args.maximum !== 1,
        groups: !!this.args.includeGroups,
        emails: !!this.args.emails,
      }),
  };

  constructor(owner: Owner, args: DSelectUserSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("DSelectUser", args);
  }

  /**
   * Both select-kit names, because the email, group and user chooser extended the user chooser
   * and answered to both.
   */
  get legacyKind() {
    return this.args.legacyKind ?? ["user-chooser", "email-group-user-chooser"];
  }

  /** Every input of the search; nested search options compare by their content. */
  get loadContext() {
    return {
      groups: this.args.includeGroups,
      emails: this.args.emails,
      exclude: this.#exclude,
      includeStaged: this.args.includeStaged,
      topicId: this.args.topicId,
      categoryId: this.args.categoryId,
      searchOptions: JSON.stringify(this.args.searchOptions ?? {}),
      showStatus: this.args.showStatus,
    };
  }

  /** A topic or category lists its users before anything is typed. */
  get minChars() {
    return this.args.topicId || this.args.categoryId ? 0 : 1;
  }

  get selectedValue() {
    const values = makeArray(this.args.value as string | string[] | null);
    return this.args.multiple ? values : (values[0] ?? null);
  }

  get #exclude(): string[] {
    const exclude = [...(this.args.exclude ?? [])];
    if (this.args.excludeCurrentUser && this.currentUser) {
      exclude.push(this.currentUser.username);
    }
    return exclude;
  }

  @action
  createUnresolvedItem(value: SelectItemId): UserPickItem {
    return { id: String(value), name: String(value) };
  }

  @action
  async load(filter: string, opts: SelectLoadOptions) {
    const rows = (await searchUsers({
      term: filter,
      groups: this.args.includeGroups,
      emails: this.args.emails,
      exclude: this.#exclude,
      includeStaged: this.args.includeStaged,
      topicId: this.args.topicId,
      categoryId: this.args.categoryId,
      searchOptions: opts.options?.searchOptions as
        | Record<string, unknown>
        | undefined,
    })) as UserSearchRow[];
    return rows.map((row) => this.#item(row));
  }

  @action
  onChange(value: SelectValue, items: SelectItem | SelectItem[] | null) {
    if (this.args.multiple) {
      this.args.onChange?.(
        makeArray(value as string | string[]).map(String),
        makeArray(items as UserPickItem | UserPickItem[] | null)
      );
      return;
    }
    this.args.onChange?.(
      value == null ? null : String(value as string),
      (items as UserPickItem | null) ?? null
    );
  }

  /**
   * Splits a pasted list on commas, spaces and newlines, dropping a leading `@`. A single
   * name, which has none of these, is typed as usual. The names are looked up together;
   * one nothing resolves is kept as typed, as select-kit kept every pasted name.
   */
  @action
  parsePaste(text: string) {
    if (!/[,\n@]/.test(text)) {
      return null;
    }
    const names = [
      ...new Map(
        text
          .split(/[,\s]+/)
          .map((name) => name.replace(/^@+/, "").trim())
          .filter(Boolean)
          .map((name) => [name.toLowerCase(), name])
      ).values(),
    ];
    if (!names.length) {
      return null;
    }
    return this.#resolve(names);
  }

  @action
  async resolveValues(
    values: SelectItemId[],
    opts: SelectLoadOptions
  ): Promise<SelectItem[]> {
    const names = values.map(String);
    const special = new Map<string, SelectItem>(
      (opts.options ? this.#specialRows(opts.options) : []).map((item) => [
        String(item.id),
        item,
      ])
    );
    const resolved = await this.#resolve(
      names.filter((name) => !special.has(name))
    );
    return [
      ...names.flatMap((name): SelectItem[] => {
        const item = special.get(name);
        return item ? [item] : [];
      }),
      ...resolved.filter((item) => item.type),
    ];
  }

  #item(row: UserSearchRow): UserPickItem {
    if (row.type === "group") {
      return {
        id: row.value,
        type: "group",
        ...groupFields({
          name: row.name ?? row.value,
          full_name: row.full_name,
        }),
      };
    }
    if (row.type === "email") {
      return { id: row.value, name: row.value, type: "email" };
    }
    const status = this.args.showStatus ? row.status : undefined;
    return {
      id: row.value,
      name: row.username ?? row.value,
      type: "user",
      username: row.username,
      avatar_template: row.avatar_template,
      fullName: row.name,
      statusEmoji: status?.emoji,
      description: status?.description,
    };
  }

  /** Items for names: special rows aside, addresses locally and the rest in one lookup. */
  async #resolve(names: string[]): Promise<UserPickItem[]> {
    const lookup = names.filter((name) => !emailValid(name));
    const rows = lookup.length
      ? ((await findUsersByUsernames(lookup, {
          groups: this.args.includeGroups,
          includeStaged: this.args.includeStaged,
        })) as UserSearchRow[])
      : [];
    const found = new Map(rows.map((row) => [row.value, this.#item(row)]));
    return names.map(
      (name) =>
        found.get(name) ??
        (emailValid(name)
          ? this.#item({ type: "email", value: name })
          : this.createUnresolvedItem(name))
    );
  }

  #specialRows(options: SelectResolvedOptions): SelectItem[] {
    return (
      this.args.specialItems?.(
        { filter: "", value: this.selectedValue, hasValue: true },
        options
      ) ?? []
    );
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family classes during rollout. }}
    <DSelect
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @clearable={{@clearable}}
      @createUnresolvedItem={{this.createUnresolvedItem}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @icon={{@icon}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @kind="select-user"
      @kindContext={{hash
        value=@value
        includeGroups=@includeGroups
        exclude=@exclude
      }}
      @kindOptions={{hash searchOptions=@searchOptions}}
      @kindTexts={{this.kindTexts}}
      @legacyKind={{this.legacyKind}}
      @load={{this.load}}
      @loadContext={{this.loadContext}}
      @maximum={{@maximum}}
      @maxVisibleChips={{@maxVisibleChips}}
      @minChars={{this.minChars}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @onClose={{@onClose}}
      @parsePaste={{if @multiple this.parsePaste}}
      @resolveValues={{this.resolveValues}}
      @specialItems={{@specialItems}}
      @suppressFooter={{not (has-block "footer")}}
      @texts={{@texts}}
      @value={{this.selectedValue}}
      @variant={{@variant}}
    >
      <:item as |item options row|>
        {{#if (has-block "item")}}
          {{yield item options row to="item"}}
        {{else}}
          <UserOption @item={{item}} />
        {{/if}}
      </:item>
      <:selection as |item options|>
        {{#if (has-block "selection")}}
          {{yield item options to="selection"}}
        {{else}}
          <UserSelection @item={{item}} @options={{options}} />
        {{/if}}
      </:selection>
      <:footer as |state options|>
        {{yield state options to="footer"}}
      </:footer>
    </DSelect>
  </template>
}
