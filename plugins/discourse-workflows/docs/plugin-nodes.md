# Plugin node loading

Contributing plugins register nodes with `register_discourse_workflows_node`.
Use the block form to defer loading until the Workflows base classes are ready.
Return the node classes from the block; the first plugin to register a node owns
its enabled check and trigger subscription.

Put node classes and shared helpers under `lib/discourse_workflows` or
`discourse_workflows` in the contributing plugin. Workflows registers these
source directories with Rails' main autoloader under the `DiscourseWorkflows`
namespace before Zeitwerk setup. Filenames must match their constants, including
helpers loaded with `require_relative` at startup.

Registrations retain constant names for named node and credential classes.
Registry lookups and event handlers resolve those names when used, so a Rails
reload picks up changed code and metadata. Do not capture reloadable classes in
persistent callbacks or cache their class objects in a plugin registration.
Anonymous node classes remain supported for dynamically constructed nodes.

Changes to plugin initialization, source directory registration, or trigger
subscriptions require a server restart. Changes to existing node implementations
and their helpers use Rails' normal development reloading.
