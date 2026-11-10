/** The preferences pages that save user attributes. */
export type PreferencesPage =
  | "account"
  | "emails"
  | "interface"
  | "navigation-menu"
  | "notifications"
  | "profile"
  | "tags"
  | "tracking"
  | "users";

/** Contract for the `preferences-save-attributes` value transformer. */
export interface PreferencesSaveAttributesTransformer {
  value: string[];
  context: { page: PreferencesPage };
  mutable: false;
}
