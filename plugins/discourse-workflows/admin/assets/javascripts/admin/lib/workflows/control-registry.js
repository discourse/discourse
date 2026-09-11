import AssignmentCollection from "../../components/workflows/configurators/assignment-collection.gjs";
import Collection from "../../components/workflows/configurators/collection.gjs";
import FixedCollection from "../../components/workflows/configurators/fixed-collection.gjs";
import FIELD_CONTROL_REGISTRY from "./field-control-registry.js";

const CONTROL_REGISTRY = {
  collection: { kind: "structural", renderer: Collection },
  fixed_collection: { kind: "structural", renderer: FixedCollection },
  assignment_collection: {
    kind: "structural",
    renderer: AssignmentCollection,
  },
  ...FIELD_CONTROL_REGISTRY,
};

export default CONTROL_REGISTRY;
