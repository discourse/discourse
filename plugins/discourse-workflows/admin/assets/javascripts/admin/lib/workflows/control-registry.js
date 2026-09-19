import AssignmentCollection from "../../components/workflows/configurators/assignment-collection";
import Collection from "../../components/workflows/configurators/collection";
import FixedCollection from "../../components/workflows/configurators/fixed-collection";
import FIELD_CONTROL_REGISTRY from "./field-control-registry";

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
