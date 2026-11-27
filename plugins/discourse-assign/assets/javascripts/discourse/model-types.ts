export interface TopicAssignment {
  id: number;
  target_id: number;
  target_type: "Topic";
  assigned_to_type: "User" | "Group";
  assigned_to: {
    id: number;
    username?: string;
    name?: string | null;
    avatar_template?: string;
  };
  note: string | null;
  /** Omitted when assignment statuses are disabled. */
  status?: string | null;
}

declare module "discourse/models/topic" {
  interface TopicFields {
    /** Omitted when assignment metadata is not visible to the viewer. */
    topic_assignments?: TopicAssignment[];
  }
}
