/* eslint-disable ember/routes-segments-snake-case */
export default function () {
  this.route("gamificationLeaderboard", { path: "/leaderboard" }, function () {
    this.route("byName", { path: "/:leaderboardId" });
  });
}
