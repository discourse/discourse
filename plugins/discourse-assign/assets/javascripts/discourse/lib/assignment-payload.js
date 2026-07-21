export default function assignmentPayload(assignment) {
  return {
    username: assignment.username,
    group_name: assignment.group_name,
    note: assignment.note,
    status: assignment.status,
  };
}
