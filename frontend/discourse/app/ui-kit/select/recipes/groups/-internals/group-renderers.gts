import type { TOC } from "@ember/component/template-only";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import type {
  SelectOption,
  SelectRecord,
} from "discourse/ui-kit/select/select-engine";

/** A group as the site and user search list it. */
export interface GroupShape {
  id?: number;
  name: string;
  full_name?: string | null;
}

/** A record's display name, narrowed for templates. */
export function recordName(record: SelectRecord): string {
  return typeof record.name === "string"
    ? record.name
    : String(record.name ?? "");
}

/** Why a disabled option can't be picked, when its record gives a reason. */
export function disabledReason(
  record: SelectRecord,
  option: SelectOption | undefined
): string | undefined {
  return option?.disabled && typeof record.disabledReason === "string"
    ? record.disabledReason
    : undefined;
}

/** A group's full name, when it says something more than its name; groups describe themselves with it. */
export function groupFullName(group: GroupShape): string | undefined {
  const fullName = group.full_name?.trim();
  return fullName && fullName !== group.name ? fullName : undefined;
}

/** A group row, shared by the user and group pickers. */
export const GroupOption: TOC<{
  Args: {
    /** The group's record. */
    record: SelectRecord;
    /** The option drawn; absent in the selection, which draws no reason. */
    option?: SelectOption;
    /** Draws the group icon, which tells groups from users in a mixed list. */
    icon?: boolean;
  };
}> = <template>
  <span class="d-group-option">
    {{#if @icon}}
      {{dIcon "users"}}
    {{/if}}
    <span class="d-group-option__name">{{recordName @record}}</span>
    {{#if (disabledReason @record @option)}}
      <span class="d-group-option__reason">
        {{~dIcon "ban"~}}
        {{~disabledReason @record @option~}}
      </span>
    {{/if}}
  </span>
</template>;
