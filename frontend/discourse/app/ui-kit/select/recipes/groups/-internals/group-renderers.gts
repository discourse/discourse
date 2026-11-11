import type { TOC } from "@ember/component/template-only";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import type { SelectRecord } from "discourse/ui-kit/select/select-engine";

/** A group as the site and user search list it. */
export interface GroupShape {
  id?: number;
  name: string;
  full_name?: string | null;
}

/** An item's display name, narrowed for templates. */
export function recordName(item: SelectRecord): string {
  return typeof item.name === "string" ? item.name : String(item.name ?? "");
}

/** Why a disabled row can't be picked, when its source gives a reason. */
export function disabledReason(item: SelectRecord): string | undefined {
  return item.disabled && typeof item.disabledReason === "string"
    ? item.disabledReason
    : undefined;
}

/**
 * A group's row fields: its name labels it, and a full name that says something more
 * becomes the row's description.
 */
export function groupFields(group: GroupShape): {
  name: string;
  description?: string;
} {
  const fullName = group.full_name?.trim();
  return {
    name: group.name,
    description: fullName && fullName !== group.name ? fullName : undefined,
  };
}

/** A group row, shared by the user and group pickers. */
export const GroupOption: TOC<{
  Args: {
    /** The group row. */
    record: SelectRecord;
    /** Draws the group icon, which tells groups from users in a mixed list. */
    icon?: boolean;
  };
}> = <template>
  <span class="d-group-option">
    {{#if @icon}}
      {{dIcon "users"}}
    {{/if}}
    <span class="d-group-option__name">{{recordName @record}}</span>
    {{#if (disabledReason @record)}}
      <span class="d-group-option__reason">
        {{~dIcon "ban"~}}
        {{~disabledReason @record~}}
      </span>
    {{/if}}
  </span>
</template>;
