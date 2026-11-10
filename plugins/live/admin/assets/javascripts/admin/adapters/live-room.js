import RestAdapter from "discourse/adapters/rest";

export default class LiveRoomAdapter extends RestAdapter {
  jsonMode = true;

  basePath() {
    return "/admin/plugins/live/";
  }

  pathFor(store, type, id) {
    return id === undefined
      ? "/admin/plugins/live/rooms.json"
      : `/admin/plugins/live/rooms/${id}.json`;
  }

  apiNameFor() {
    return "room";
  }
}
