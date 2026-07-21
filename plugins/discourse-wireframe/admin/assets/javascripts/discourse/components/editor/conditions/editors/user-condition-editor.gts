import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { type ComponentLike } from "@glint/template";
import type Site from "discourse/models/site";
import GroupChooserUntyped from "discourse/select-kit/components/group-chooser";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

/**
 * The shape of a `user` condition leaf. Every field is optional: an unset
 * field means the condition does not constrain that dimension. The evaluator
 * reads exactly these keys, and the editor omits any field the author clears
 * so the serialised JSON stays compact.
 */
export interface UserConditionLeaf {
  type?: string;
  loggedIn?: boolean;
  admin?: boolean;
  moderator?: boolean;
  staff?: boolean;
  minTrustLevel?: number;
  maxTrustLevel?: number;
  groups?: string[];
}

interface UserConditionEditorSignature {
  Args: {
    leaf: UserConditionLeaf;
    onChange: (next: UserConditionLeaf) => void;
  };
  Element: HTMLDivElement;
}

// TODO(devxp-typescript-pending): drop once GroupChooser is authored in .gts
// with a real Signature, then import it directly. It is an untyped select-kit
// component today, so it exposes no arg/attr types.
const GroupChooser = GroupChooserUntyped as unknown as ComponentLike<{
  Args: {
    content?: unknown[];
    value?: string[];
    valueProperty?: string;
    labelProperty?: string;
    onChange?: (value: string[]) => void;
    options?: object;
  };
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
const TRUST_LEVELS = [
  { value: 0, label: "TL0" },
  { value: 1, label: "TL1" },
  { value: 2, label: "TL2" },
  { value: 3, label: "TL3" },
  { value: 4, label: "TL4" },
];

export default class UserConditionEditor extends Component<UserConditionEditorSignature> {
  @service declare site: Site;

  get loginMode() {
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
  get availableGroups() {
    return (
      this.site.groups?.filter((g: { automatic?: boolean }) => !g.automatic) ??
      []
    );
  }

  get selectedGroupNames() {
    return Array.isArray(this.args.leaf.groups) ? this.args.leaf.groups : [];
  }

  patch(patch: Partial<UserConditionLeaf>) {
    const next: UserConditionLeaf = { ...this.args.leaf };
    for (const [key, value] of Object.entries(patch) as [
      keyof UserConditionLeaf,
      UserConditionLeaf[keyof UserConditionLeaf],
    ][]) {
      if (value === undefined) {
        delete next[key];
      } else {
        // `key` and `value` are a matched pair from the same partial, but TS
        // widens `value` to the union of all field types across the loop, so
        // the assignment goes through an index cast at this dynamic boundary.
        (next as Record<string, unknown>)[key] = value;
      }
    }
    this.args.onChange(next);
  }

  @action
  setLoginMode(mode: "any" | "logged-in" | "anonymous") {
    if (mode === "any") {
      this.patch({ loggedIn: undefined });
    } else if (mode === "logged-in") {
      this.patch({ loggedIn: true });
    } else {
      this.patch({ loggedIn: false });
    }
  }

  @action
  toggleRole(name: "admin" | "moderator" | "staff", event: Event) {
    const checked = (event.target as HTMLInputElement).checked;
    this.patch({ [name]: checked ? true : undefined });
  }

  @action
  setTrustLevel(which: "minTrustLevel" | "maxTrustLevel", event: Event) {
    const raw = (event.target as HTMLSelectElement).value;
    if (raw === "") {
      this.patch({ [which]: undefined });
      return;
    }
    const parsed = Number(raw);
    if (Number.isFinite(parsed) && parsed >= 0 && parsed <= 4) {
      this.patch({ [which]: parsed });
    }
  }

  @action
  setGroups(names: string[]) {
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
