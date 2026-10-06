import RestAdapter from "discourse/adapters/rest";

export default class VoiceRoomAdapter extends RestAdapter {
  jsonMode = true;

  basePath() {
    return "/admin/plugins/voice/";
  }

  pathFor(store, type, id) {
    return id === undefined
      ? "/admin/plugins/voice/rooms.json"
      : `/admin/plugins/voice/rooms/${id}.json`;
  }

  apiNameFor() {
    return "room";
  }
}
