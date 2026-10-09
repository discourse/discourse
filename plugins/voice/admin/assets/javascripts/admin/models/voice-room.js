import RestModel from "discourse/models/rest";

const SAVED_PROPERTIES = [
  "name",
  "description",
  "public",
  "max_participants",
  "video_enabled",
  "livekit_enabled",
  "chat_channel_id",
  "chat_idle_minutes",
];

// A cleared FormKit <field.Control @type="select"> reports `undefined`
// (its "None" option), and this model's adapter JSON-encodes properties for
// the request body — JSON.stringify drops `undefined`-valued keys entirely,
// so clearing a nullable field like chat_channel_id would silently never
// reach the server. Send an explicit `null` instead.
function withNullsForUndefined(properties) {
  const normalized = { ...properties };
  for (const key of Object.keys(normalized)) {
    if (normalized[key] === undefined) {
      normalized[key] = null;
    }
  }
  return normalized;
}

export default class VoiceRoom extends RestModel {
  createProperties() {
    return withNullsForUndefined(this.getProperties(SAVED_PROPERTIES));
  }

  updateProperties() {
    return withNullsForUndefined(this.getProperties(SAVED_PROPERTIES));
  }
}
