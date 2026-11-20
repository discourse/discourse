declare module "discourse/models/reviewable" {
  interface ReviewableFields {
    /** Present when the reviewer can perform the suggested action on a pending item. */
    ai_suggested_action_name?: string;
  }
}

export {};
