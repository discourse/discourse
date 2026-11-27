# Assign Plugin

Allows you to assign topics and individual posts (both private and public) to a user or group.

Enable `assign_allow_multiple_topic_assignees` to assign multiple users and at most one group to a topic, with separate notes and statuses. Individual posts retain one assignee. The hidden `assign_max_assignments_per_topic` setting defaults to 20 active assignments across a topic and its posts.

See the [assignment investigation](docs/topic-assignments.md) and [implementation plan and notes](docs/multiple-topic-assignments-plan.md) for API compatibility, deployment, and UI details.

For more information, please see: https://meta.discourse.org/t/discourse-assign/58044
