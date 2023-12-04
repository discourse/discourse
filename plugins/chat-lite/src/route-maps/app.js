import WowRoute from "../routes/wow.gjs";

export default function (mapper) {
  mapper.route("wow", {}, WowRoute);
}
