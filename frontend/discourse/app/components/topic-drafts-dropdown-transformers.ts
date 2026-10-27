import type UserDraft from "discourse/models/user-draft";

/** Contract for the `draft-icon` value transformer. */
export interface DraftIconTransformer {
  value: string;
  context: { draft: UserDraft };
  mutable: false;
}
