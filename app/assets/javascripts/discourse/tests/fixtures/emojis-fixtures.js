import { IMAGE_VERSION as v } from "pretty-text/emoji/version";

export default {
  "/emojis.json": {
     favorites: [
      {
        name: "grinning",
        tonable: false,
        url: `/images/emoji/twitter/grinning.png?v=${v}`,
        group: "smileys_\u0026_emotion",
        search_aliases: ["smiley_cat", "star_struck"],
      },
    ],
    "smileys_&_emotion": [
      {
        name: "grinning",
        tonable: false,
        url: `/images/emoji/twitter/grinning.png?v=${v}`,
        group: "smileys_\u0026_emotion",
        search_aliases: ["smiley_cat", "star_struck"],
      },
      {
        name: "smiley_cat",
        tonable: false,
        url: `/images/emoji/twitter/smiley_cat.png?v=${v}`,
        group: "smileys_\u0026_emotion",
      },
    ],
    "people_&_body": [
      {
        name: "raised_hands",
        tonable: true,
        url: `/images/emoji/twitter/raised_hands.png?v=${v}`,
        group: "people_&_body",
        search_aliases: [],
      },
      {
        name: "man_rowing_boat",
        tonable: true,
        url: `/images/emoji/twitter/man_rowing_boat.png?v=${v}`,
        group: "people_&_body",
        search_aliases: [],
      },
    ],
    objects: [
      {
        name: "womans_clothes",
        tonable: false,
        url: `/images/emoji/twitter/womans_clothes.png?v=${v}`,
        group: "objects",
        search_aliases: [],
      },
    ]
  }
}
