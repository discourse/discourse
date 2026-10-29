declare module "discourse/models/topic" {
  interface TopicFields {
    /** Omitted from topic lists for topics that aren't regular topics. */
    can_vote?: boolean;
    /** Omitted from topic lists for topics that can't be voted on. */
    vote_count?: number;
    /** Null in topic lists for anonymous users. */
    user_voted?: boolean | null;
  }
}

declare module "discourse/models/category" {
  interface CategoryFields {
    /** Sent only for categories that allow voting. */
    can_vote?: true;
  }
}

export {};
