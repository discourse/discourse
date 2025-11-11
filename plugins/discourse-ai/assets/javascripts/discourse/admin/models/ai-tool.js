import { TrackedArray, TrackedObject } from "@ember-compat/tracked-built-ins";
import RestModel from "discourse/models/rest";

const CREATE_ATTRIBUTES = [
  "id",
  "name",
  "tool_name",
  "description",
  "parameters",
  "script",
  "summary",
  "rag_uploads",
  "rag_chunk_tokens",
  "rag_chunk_overlap_tokens",
  "rag_llm_model_id",
  "enabled",
];

export default class AiTool extends RestModel {
  createProperties() {
    return this.getProperties(CREATE_ATTRIBUTES);
  }

  updateProperties() {
    return this.getProperties(CREATE_ATTRIBUTES);
  }

  trackParameters(parameters) {
    return new TrackedArray(
      parameters?.map((p) => {
        const parameter = new TrackedObject(p);

        if (parameter.enum && parameter.enum.length) {
          parameter.enum = new TrackedArray(parameter.enum);
        } else {
          parameter.enum = null;
        }

        return parameter;
      })
    );
  }

  workingCopy() {
    const attrs = this.getProperties(CREATE_ATTRIBUTES);
    attrs.parameters = this.trackParameters(attrs.parameters);
    return this.store.createRecord("ai-tool", attrs);
  }
}
