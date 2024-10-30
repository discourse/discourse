import User from "discourse/models/user";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";

let channels = {};

export default function (helper) {
  this.post("/presence/update", (request) => {
    const params = new URLSearchParams(request.requestBody);
    const presentChannels = params.getAll("present_channels[]");
    const leaveChannels = params.getAll("leave_channels[]");

    const user = User.current();
    if (!user) {
      return helper.response(403, {});
    }
    const userInfo = {
      id: user.id,
      username: user.username,
      name: user.name,
      avatar_template: "/letter_avatar_proxy/v4/letter/b/35a633/{size}.png",
    };

    presentChannels.forEach((c) => joinChannel(c, userInfo));
    leaveChannels.forEach((c) => leaveChannel(c, userInfo));

    return helper.response({ success: "OK" });
  });
  this.get("/presence/get", (request) => {
    const channelNames = request.queryParams.channels;
    const response = {};
    channelNames.forEach((c) => (response[c] = getChannelInfo(c)));
    return helper.response(response);
  });
}

export function getChannelInfo(name) {
  return (channels[name] ||= { count: 0, users: [], last_message_id: 0 });
}

export async function joinChannel(name, user) {
  const channel = getChannelInfo(name);
  if (!channel.users.any((u) => u.id === user.id)) {
    channel.users.push(user);
    channel.count += 1;
    channel.last_message_id += 1;
    await publishToMessageBus(
      `/presence${name}`,
      {
        entering_users: [{ ...user }],
      },
      0,
      channel.last_message_id
    );
  }
}

export async function leaveChannel(name, user) {
  const channel = getChannelInfo(name);
  if (channel.users.any((u) => u.id === user.id)) {
    channel.users = channel.users.reject((u) => u.id === user.id);
    channel.count -= 1;
    channel.last_message_id += 1;
    await publishToMessageBus(
      `/presence${name}`,
      {
        leaving_user_ids: [user.id],
      },
      0,
      channel.last_message_id
    );
  }
}

export function presentUserIds(channelName) {
  return getChannelInfo(channelName).users.map((u) => u.id);
}

export function clearState() {
  channels = {};
}
