import { i18n } from "discourse-i18n";
import { STICKY_NOTE_TYPE } from "../../models/sticky-note.js";
import { workflowFromTemplate } from "./template-workflow.js";

export const MAX_NODES = 50;

// The server rejects these node keys as unsupported legacy field names.
// Surfacing them client-side saves the user a confusing 422 round trip.
const UNSUPPORTED_NODE_KEYS = [
  "type_version",
  "webhook_id",
  "position_index",
  "settings",
];

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function error(key, options = {}) {
  return i18n(`discourse_workflows.import_workflow.${key}`, options);
}

function collectNodeErrors(nodes, errors) {
  if (!Array.isArray(nodes)) {
    errors.push(error("invalid_nodes"));
    return;
  }

  if (nodes.length === 0) {
    errors.push(error("nodes_required"));
    return;
  }

  if (nodes.length > MAX_NODES) {
    errors.push(
      error("too_many_nodes", { count: nodes.length, max: MAX_NODES })
    );
  }

  const executableNames = {};
  const stickyNoteNames = {};
  const knownNodeNames = {};
  nodes.forEach((node, index) => {
    if (!isPlainObject(node)) {
      errors.push(error("invalid_node", { index: index + 1 }));
      return;
    }

    if (typeof node.type !== "string" || node.type.trim() === "") {
      errors.push(error("node_type_required", { index: index + 1 }));
    }

    if (typeof node.name !== "string" || node.name.trim() === "") {
      errors.push(error("node_name_required", { index: index + 1 }));
    }

    if (typeof node.name === "string" && node.name.trim() !== "") {
      knownNodeNames[node.name] = true;

      // The server only rejects duplicate executable node names, plus
      // sticky note names that collide with an executable name. Multiple
      // sticky notes sharing a name are valid (the editor defaults every
      // note to "Sticky Note", and bundled templates contain several), so
      // match that here instead of rejecting every repeated name.
      if (node.type === STICKY_NOTE_TYPE) {
        if (executableNames[node.name]) {
          errors.push(error("duplicate_node_name", { name: node.name }));
        }
        stickyNoteNames[node.name] = true;
      } else {
        if (executableNames[node.name] || stickyNoteNames[node.name]) {
          errors.push(error("duplicate_node_name", { name: node.name }));
        }
        executableNames[node.name] = true;
      }
    }

    UNSUPPORTED_NODE_KEYS.forEach((key) => {
      if (key in node) {
        errors.push(error("unsupported_node_key", { key, index: index + 1 }));
      }
    });
  });

  return knownNodeNames;
}

function validateConnections(connections, knownNodeNames, errors) {
  if (connections === undefined || connections === null) {
    return;
  }

  if (!isPlainObject(connections)) {
    errors.push(error("invalid_connections"));
    return;
  }

  Object.entries(connections).forEach(([sourceNode, endpoints]) => {
    if (!knownNodeNames[sourceNode]) {
      errors.push(error("unknown_connection_source", { node: sourceNode }));
    }

    if (!isPlainObject(endpoints)) {
      errors.push(error("invalid_connections"));
      return;
    }

    Object.values(endpoints).forEach((portLists) => {
      if (!Array.isArray(portLists)) {
        errors.push(error("invalid_connections"));
        return;
      }

      portLists.forEach((connectionsForPort) => {
        if (!Array.isArray(connectionsForPort)) {
          errors.push(error("invalid_connections"));
          return;
        }

        connectionsForPort.forEach((connection) => {
          if (
            !isPlainObject(connection) ||
            typeof connection.node !== "string"
          ) {
            errors.push(error("invalid_connections"));
            return;
          }

          if (!knownNodeNames[connection.node]) {
            errors.push(
              error("unknown_connection_target", { node: connection.node })
            );
          }
        });
      });
    });
  });
}

/**
 * Parse a pasted workflow JSON payload and validate its shape the same way
 * Workflow::Create and WorkflowGraphValidator do server-side. Returns either
 * a normalized workflow payload ready for POSTing, or a list of
 * human-readable errors.
 */
export function buildWorkflowFromJson(text, { name } = {}) {
  const errors = [];

  if (typeof text !== "string" || text.trim() === "") {
    return { workflow: null, errors: [error("empty")] };
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { workflow: null, errors: [error("invalid_json")] };
  }

  if (!isPlainObject(parsed)) {
    return { workflow: null, errors: [error("invalid_payload")] };
  }

  if (typeof name === "string" && name.trim()) {
    parsed.name = name.trim();
  }

  if (typeof parsed.name !== "string" || parsed.name.trim() === "") {
    errors.push(error("name_required"));
  }

  const knownNodeNames = collectNodeErrors(parsed.nodes, errors);
  validateConnections(parsed.connections, knownNodeNames || {}, errors);

  if (Object.hasOwn(parsed, "staticData")) {
    if (invalidStaticData(parsed.staticData)) {
      errors.push(error("invalid_static_data"));
    }
  }

  if (Object.hasOwn(parsed, "variables")) {
    if (
      !Array.isArray(parsed.variables) ||
      parsed.variables.some((variables) => !isPlainObject(variables))
    ) {
      errors.push(error("invalid_variables"));
    }
  }

  if (Object.hasOwn(parsed, "settings") && invalidSettings(parsed.settings)) {
    errors.push(error("invalid_settings"));
  }

  if (errors.length > 0) {
    return { workflow: null, errors };
  }

  // workflowFromTemplate strips unknown keys and passes through the fields
  // Workflow::Create understands, matching the template import path exactly.
  // Exported workflows carry variables, staticData, and settings beyond the
  // graph, so keep them here to make a paste round trip lossless.
  let workflow = workflowFromTemplate(parsed);
  if (Object.hasOwn(parsed, "staticData")) {
    workflow = { ...workflow, staticData: parsed.staticData };
  }
  if (Object.hasOwn(parsed, "variables")) {
    workflow = { ...workflow, variables: parsed.variables };
  }
  if (Object.hasOwn(parsed, "settings")) {
    workflow = { ...workflow, settings: parsed.settings };
  }
  return { workflow, errors };
}

// Mirrors DiscourseWorkflows::Workflow.valid_static_data_map?: a map of
// node names to data slots, with values being objects (static_data_slot
// coerces nothing to a Hash, so anything else fails server-side).
function invalidStaticData(staticData) {
  return (
    !isPlainObject(staticData) ||
    Object.hasOwn(staticData, "node") ||
    Object.values(staticData).some((slot) => !isPlainObject(slot))
  );
}

// Reject invalid timezones before creating the workflow: settings are saved
// through a separate request after creation.
function invalidSettings(settings) {
  return (
    !isPlainObject(settings) ||
    (Object.hasOwn(settings, "timezone") &&
      (typeof settings.timezone !== "string" ||
        !moment.tz.names().includes(settings.timezone)))
  );
}
