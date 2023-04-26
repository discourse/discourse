import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("display-creator-name", function (posters) {
  let creatorName = "";
  for (let i = 0; i < posters.length; i++) {
    if (posters[i].description.toLowerCase().includes("original poster")) {
      creatorName = posters[i].user.name
        ? posters[i].user.name
        : posters[i].user.username;
    }
  }
  if (creatorName.length > 15) {
    creatorName =
      creatorName.substring(0, 3) +
      "..." +
      creatorName.substring(creatorName.length - 8);
  }
  return creatorName;
});

registerUnbound("path-to-creator", function (posters) {
  let creatorUserName = "";
  for (let i = 0; i < posters.length; i++) {
    if (posters[i].description.toLowerCase().includes("original poster")) {
      creatorUserName = posters[i].user.username;
    }
  }
  return "/u/" + creatorUserName + "/summary";
});
