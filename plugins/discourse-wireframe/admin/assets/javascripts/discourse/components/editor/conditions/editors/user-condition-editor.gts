import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { type ComponentLike } from "@glint/template";
import type SiteService from "discourse/models/site";
import GroupChooserUntyped from "discourse/select-kit/components/group-chooser";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import type { ConditionLeaf } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";

/**
 * The shape of a `user` condition leaf. Every field is optional: an unset
 * field means the condition does not constrain that dimension. The evaluator
 * reads exactly these keys, and the editor omits any field the author clears
 * so the serialised JSON stays compact.
 */
export type UserConditionLeaf = ConditionLeaf & {
  /** Whether the viewer must be logged in. */
  loggedIn?: boolean;
  /** Whether the viewer must be an administrator. */
  admin?: boolean;
  /** Whether the viewer must be a moderator. */
  moderator?: boolean;
  /** Whether the viewer must be a staff member. */
  staff?: boolean;
  /** Minimum required trust level. */
  minTrustLevel?: number;
  /** Maximum permitted trust level. */
  maxTrustLevel?: number;
  /** Required group memberships. */
  groups?: string[];
};

type LoginMode = "any" | "logged-in" | "anonymous";
type UserRole = "admin" | "moderator" | "staff";
type TrustLevelField = "minTrustLevel" | "maxTrustLevel";

type TrustLevelOption = {
  /** Numeric trust level. */
  value: number;
  /** Short display label. */
  label: string;
};

interface UserConditionEditorSignature {
  /** User condition and update callback. */
  Args: {
    /** User condition leaf being edited. */
    leaf: UserConditionLeaf;
    /** Replaces the edited condition leaf. */
    onChange: (
      /** Updated user condition leaf. */
      next: UserConditionLeaf
    ) => void;
  };
  /** Root element containing the user condition controls. */
  Element: HTMLDivElement;
}

// TODO(devxp-typescript-pending): drop once GroupChooser is authored in .gts
// with a real Signature, then import it directly. It is an untyped select-kit
// component today, so it exposes no arg/attr types.
const GroupChooser = GroupChooserUntyped as unknown as ComponentLike<{
  /** Select-kit arguments consumed by this editor. */
  Args: {
    /** Groups available for selection. */
    content?: unknown[];
    /** Selected group names. */
    value?: string[];
    /** Property used as the option value. */
    valueProperty?: string;
    /** Property used as the option label. */
    labelProperty?: string;
    /** Called with the selected group names. */
    onChange?: (
      /** Selected group names. */
      value: string[]
    ) => void;
    /** Select-kit behavior options. */
    options?: {
      /** Translation key for the filter placeholder. */
      filterPlaceholder?: string;
    };
  };
  /** Root select-kit element. */
  Element: HTMLDivElement;
}>;

/**
 * Context-sensitive editor for the `user` condition. Surfaces the
 * fields the condition's evaluator actually reads:
 *
 *  - **Login state** — segmented chips: Any / Logged in / Anonymous.
 *  - **Role** — checkbox row: Admin / Moderator / Staff. These are
 *     AND-combined by the evaluator: every checked role must hold for
 *     the condition to pass.
 *  - **Trust level** — min / max selects with TL0–TL4 labels.
 *  - **Groups** — `<GroupChooser>` configured to deal in names so
 *     the schema (`groups: ["staff", "trust_level_2"]`) round-trips
 *     without an id↔name mapping layer.
 *
 * Emits a fully-formed leaf via `@onChange(nextLeaf)` on every edit.
 * Unset args are omitted entirely so the serialised JSON stays
 * compact.
 */
const TRUST_LEVELS: readonly TrustLevelOption[] = [
  { value: 0, label: "TL0" },
  { value: 1, label: "TL1" },
  { value: 2, label: "TL2" },
  { value: 3, label: "TL3" },
  { value: 4, label: "TL4" },
];

export default class UserConditionEditor extends Component<UserConditionEditorSignature> {
  /** Provides groups available on the current site. */
  @service declare site: SiteService;

  /** Login-state segment represented by the current condition. */
  get loginMode(): LoginMode {
    if (this.args.leaf.loggedIn === true) {
      return "logged-in";
    }
    if (this.args.leaf.loggedIn === false) {
      return "anonymous";
    }
    return "any";
  }

  /**
   * Selectable groups — strips out the automatic groups since the
   * evaluator works against user-membership and most automatic groups
   * (`everyone`, `trust_level_n`) don't make sense to pick by hand for
   * an explicit-membership check. Authors who genuinely need a TL
   * gate use the trust-level controls instead.
   */
  get availableGroups(): unknown[] {
    const groups: unknown = this.site.groups;
    return Array.isArray(groups)
      ? groups.filter((group) => !isAutomaticGroup(group))
      : [];
  }

  /** Selected group names. */
  get selectedGroupNames(): string[] {
    return Array.isArray(this.args.leaf.groups) ? this.args.leaf.groups : [];
  }

  /**
   * Applies a partial user-condition update, deleting undefined fields.
   *
   * @param patch - Condition fields to replace or remove.
   */
  patch(patch: Partial<UserConditionLeaf>): void {
    const next = { ...this.args.leaf };
    for (const [key, value] of Object.entries(patch)) {
      if (value === undefined) {
        delete next[key];
      } else {
        next[key] = value;
      }
    }
    this.args.onChange(next);
  }

  /**
   * Updates the required login state.
   *
   * @param mode - Login mode selected by the author.
   */
  @action
  setLoginMode(mode: LoginMode): void {
    if (mode === "any") {
      this.patch({ loggedIn: undefined });
    } else if (mode === "logged-in") {
      this.patch({ loggedIn: true });
    } else {
      this.patch({ loggedIn: false });
    }
  }

  /**
   * Toggles a required user role.
   *
   * @param name - Role field to update.
   * @param event - Role-checkbox event.
   */
  @action
  toggleRole(name: UserRole, event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    const checked = event.currentTarget.checked;
    this.patch({ [name]: checked ? true : undefined });
  }

  /**
   * Updates one trust-level bound.
   *
   * @param which - Trust-level bound to update.
   * @param event - Trust-level selector event.
   */
  @action
  setTrustLevel(which: TrustLevelField, event: Event): void {
    if (!(event.currentTarget instanceof HTMLSelectElement)) {
      return;
    }
    const raw = event.currentTarget.value;
    if (raw === "") {
      this.patch({ [which]: undefined });
      return;
    }
    const parsed = Number(raw);
    if (Number.isFinite(parsed) && parsed >= 0 && parsed <= 4) {
      this.patch({ [which]: parsed });
    }
  }

  /**
   * Updates the required group names.
   *
   * @param names - Selected group names.
   */
  @action
  setGroups(names: string[]): void {
    if (!names || names.length === 0) {
      this.patch({ groups: undefined });
      return;
    }
    this.patch({ groups: [...names] });
  }

  <template>
    <div class="wireframe-condition-editor wireframe-condition-editor--user">
      <div class="wireframe-condition-editor__field">
        <span class="wireframe-condition-editor__legend">
          {{i18n "wireframe.inspector.conditions.user_editor.login_legend"}}
        </span>
        <div class="wireframe-condition-editor__segmented" role="radiogroup">
          <DButton
            class={{dConcatClass
              "wireframe-condition-editor__segment"
              (if (eq this.loginMode "any") "--active")
            }}
            @ariaPressed={{eq this.loginMode "any"}}
            @label="wireframe.inspector.conditions.user_editor.login_any"
            @action={{fn this.setLoginMode "any"}}
          />
          <DButton
            class={{dConcatClass
              "wireframe-condition-editor__segment"
              (if (eq this.loginMode "logged-in") "--active")
            }}
            @ariaPressed={{eq this.loginMode "logged-in"}}
            @label="wireframe.inspector.conditions.user_editor.login_logged_in"
            @action={{fn this.setLoginMode "logged-in"}}
          />
          <DButton
            class={{dConcatClass
              "wireframe-condition-editor__segment"
              (if (eq this.loginMode "anonymous") "--active")
            }}
            @ariaPressed={{eq this.loginMode "anonymous"}}
            @label="wireframe.inspector.conditions.user_editor.login_anonymous"
            @action={{fn this.setLoginMode "anonymous"}}
          />
        </div>
      </div>

      <div class="wireframe-condition-editor__field">
        <span class="wireframe-condition-editor__legend">
          {{i18n "wireframe.inspector.conditions.user_editor.role_legend"}}
        </span>
        <div class="wireframe-condition-editor__check-row">
          <label class="wireframe-condition-editor__check">
            <input
              type="checkbox"
              checked={{@leaf.admin}}
              {{on "change" (fn this.toggleRole "admin")}}
            />
            <span>{{i18n
                "wireframe.inspector.conditions.user_editor.admin"
              }}</span>
          </label>
          <label class="wireframe-condition-editor__check">
            <input
              type="checkbox"
              checked={{@leaf.moderator}}
              {{on "change" (fn this.toggleRole "moderator")}}
            />
            <span>{{i18n
                "wireframe.inspector.conditions.user_editor.moderator"
              }}</span>
          </label>
          <label class="wireframe-condition-editor__check">
            <input
              type="checkbox"
              checked={{@leaf.staff}}
              {{on "change" (fn this.toggleRole "staff")}}
            />
            <span>{{i18n
                "wireframe.inspector.conditions.user_editor.staff"
              }}</span>
          </label>
        </div>
      </div>

      <div class="wireframe-condition-editor__field">
        <span class="wireframe-condition-editor__legend">
          {{i18n "wireframe.inspector.conditions.user_editor.trust_legend"}}
        </span>
        <div class="wireframe-condition-editor__pair">
          <label class="wireframe-condition-editor__pair-cell">
            <span>{{i18n
                "wireframe.inspector.conditions.user_editor.trust_min"
              }}</span>
            <select {{on "change" (fn this.setTrustLevel "minTrustLevel")}}>
              <option value="" selected={{eq @leaf.minTrustLevel undefined}}>
                —
              </option>
              {{#each TRUST_LEVELS as |tl|}}
                <option
                  value={{tl.value}}
                  selected={{eq @leaf.minTrustLevel tl.value}}
                >{{tl.label}}</option>
              {{/each}}
            </select>
          </label>
          <label class="wireframe-condition-editor__pair-cell">
            <span>{{i18n
                "wireframe.inspector.conditions.user_editor.trust_max"
              }}</span>
            <select {{on "change" (fn this.setTrustLevel "maxTrustLevel")}}>
              <option value="" selected={{eq @leaf.maxTrustLevel undefined}}>
                —
              </option>
              {{#each TRUST_LEVELS as |tl|}}
                <option
                  value={{tl.value}}
                  selected={{eq @leaf.maxTrustLevel tl.value}}
                >{{tl.label}}</option>
              {{/each}}
            </select>
          </label>
        </div>
      </div>

      <div class="wireframe-condition-editor__field">
        <span class="wireframe-condition-editor__legend">
          {{i18n "wireframe.inspector.conditions.user_editor.groups_label"}}
        </span>
        <GroupChooser
          @content={{this.availableGroups}}
          @value={{this.selectedGroupNames}}
          @valueProperty="name"
          @labelProperty="name"
          @onChange={{this.setGroups}}
          @options={{hash
            filterPlaceholder="wireframe.inspector.conditions.user_editor.groups_placeholder"
          }}
        />
      </div>
    </div>
  </template>
}

/**
 * Checks whether a site group is automatic.
 *
 * @param group - Runtime site-group value.
 * @returns Whether the group is automatic.
 */
function isAutomaticGroup(group: unknown): boolean {
  return (
    typeof group === "object" &&
    group !== null &&
    Reflect.get(group, "automatic") === true
  );
}
