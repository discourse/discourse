# Discourse Workflows

## Plugin-managed workflows

A plugin can register a `:workflow_managed_by` modifier. It receives the current
ownership metadata (or `nil`) and the workflow, and returns either the existing
value or `{ name:, url:, configuration_name: }` for a workflow it owns. Determine
ownership from server-side configuration, rather than client-submitted fields.

Managed definitions have a read-only view with configuration and duplication
links. Execution inspection remains available. Definition mutation APIs (including
publication, restoration, variables, and AI editing) reject managed workflows.
The owning plugin can update/publish them through the workflow services. A duplicate
is created as a normal unpublished workflow and does not inherit ownership.

The HTTP request node's `dry_run` option returns the planned method and URL with
`simulated: true`; it does not send an HTTP request or resolve credentials. This
can be used for published integration demonstrations. It defaults to `false`.

The workflow list separates managed workflows into a second table below regular
workflows. Search and tag filters apply to both sections, and pagination continues
loading the shared result set from the bottom table. Editable duplicates remain
in the regular table.
