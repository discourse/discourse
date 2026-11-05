import "discourse/plugins/discourse-assign/discourse/model-types";
import type { TopicFields } from "discourse/models/topic";

interface ExpectedAssignment {
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
  status?: string | null;
}

type Equal<Actual, Expected> =
  (<Value>() => Value extends Actual ? 1 : 2) extends <
    Value,
  >() => Value extends Expected ? 1 : 2
    ? true
    : false;
type Assert<Value extends true> = Value;

export type TopicAssignmentsTypeTest = Assert<
  Equal<TopicFields["topic_assignments"], ExpectedAssignment[] | undefined>
>;
