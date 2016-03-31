import groups from 'discourse/lib/emoji/emoji-groups';
import KeyValueStore from "discourse/lib/key-value-store";

const keyValueStore = new KeyValueStore("discourse_emojis_");
const EMOJI_USAGE = "emojiUsage";

let PER_ROW = 12;
const PER_PAGE = 60;

let ungroupedIcons, recentlyUsedIcons;

if (!keyValueStore.getObject(EMOJI_USAGE)) {
  keyValueStore.setObject({key: EMOJI_USAGE, value: {}});
}

function closeSelector() {
  $('.emoji-modal, .emoji-modal-wrapper').remove();
  $('body, textarea').off('keydown.emoji');
}

function initializeUngroupedIcons() {
  const groupedIcons = {};

  groups.forEach(group => {
    group.icons.forEach(icon => groupedIcons[icon] = true);
  });

  ungroupedIcons = [];
  const emojis = Discourse.Emoji.list();
  emojis.forEach(emoji => {
    if (groupedIcons[emoji] !== true) {
      ungroupedIcons.push(emoji);
    }
  });

  if (ungroupedIcons.length) {
    groups.push({name: 'ungrouped', icons: ungroupedIcons});
  }
}

function trackEmojiUsage(title) {
  const recent = keyValueStore.getObject(EMOJI_USAGE) || {};

  if (!recent[title]) { recent[title] = { title: title, usage: 0 }; }
  recent[title]["usage"]++;

  keyValueStore.setObject({key: EMOJI_USAGE, value: recent});

  // clear the cache
  recentlyUsedIcons = null;
}

function sortByUsage(a, b) {
  if (a.usage > b.usage) { return -1; }
  if (b.usage > a.usage) { return 1; }
  return a.title.localeCompare(b.title);
}

function initializeRecentlyUsedIcons() {
  recentlyUsedIcons = [];

  const usage = _.map(keyValueStore.getObject(EMOJI_USAGE)).sort(sortByUsage);
  const recent = usage.slice(0, PER_ROW);

  if (recent.length > 0) {

    recent.forEach(emoji => recentlyUsedIcons.push(emoji.title));

    const recentGroup = groups.findProperty('name', 'recent');
    if (recentGroup) {
      recentGroup.icons = recentlyUsedIcons;
    } else {
      groups.push({ name: 'recent', icons: recentlyUsedIcons });
    }
  }
}

function toolbar(selected) {
  if (!ungroupedIcons) { initializeUngroupedIcons(); }
  if (!recentlyUsedIcons) { initializeRecentlyUsedIcons(); }

  return groups.map((g, i) => {
    let icon = g.tabicon;
    let title = g.fullname;
    if (g.name === "recent") {
      icon = "star";
      title = "Recent";
    } else if (g.name === "ungrouped") {
      icon = g.icons[0];
      title = "Custom";
    }

    return { src: Discourse.Emoji.urlFor(icon),
             title,
             groupId: i,
             selected: i === selected };
  });
}

function bindEvents(page, offset, options) {
  $('.emoji-page a').click(e => {
    const title = $(e.currentTarget).attr('title');
    trackEmojiUsage(title);
    options.onSelect(title);
    closeSelector();
    return false;
  }).hover(e => {
    const title = $(e.currentTarget).attr('title');
    const html = "<img src='" + Discourse.Emoji.urlFor(title) + "' class='emoji'> <span>:" + title + ":<span>";
    $('.emoji-modal .info').html(html);
  }, () => $('.emoji-modal .info').html(""));

  $('.emoji-modal .nav .next a').click(() => render(page, offset+PER_PAGE, options));
  $('.emoji-modal .nav .prev a').click(() => render(page, offset-PER_PAGE, options));

  $('.emoji-modal .toolbar a').click(function(){
    const p = parseInt($(this).data('group-id'));
    render(p, 0, options);
    return false;
  });
}

function render(page, offset, options) {
  keyValueStore.set({key: "emojiPage", value: page});
  keyValueStore.set({key: "emojiOffset", value: offset});

  const toolbarItems = toolbar(page);
  const rows = [];
  let row = [];
  const icons = groups[page].icons;
  const max = offset + PER_PAGE;

  for(let i=offset; i<max; i++){
    if(!icons[i]){ break; }
    if(row.length === PER_ROW){
      rows.push(row);
      row = [];
    }
    row.push({src: Discourse.Emoji.urlFor(icons[i]), title: icons[i]});
  }
  rows.push(row);

  const model = {
    toolbarItems: toolbarItems,
    rows: rows,
    prevDisabled: offset === 0,
    nextDisabled: (max + 1) > icons.length
  };

  $('.emoji-modal', options.appendTo).remove();
  const template = options.container.lookup('template:emoji-toolbar.raw');
  options.appendTo.append(template(model));

  bindEvents(page, offset, options);
}

function showSelector(options) {
  options = options || {};
  options.appendTo = options.appendTo || $('body');

  options.appendTo.append('<div class="emoji-modal-wrapper"></div>');
  $('.emoji-modal-wrapper').click(() => closeSelector());

  if (Discourse.Site.currentProp('mobileView')) { PER_ROW = 9; }
  const page = keyValueStore.getInt("emojiPage", 0);
  const offset = keyValueStore.getInt("emojiOffset", 0);

  render(page, offset, options);

  $('body, textarea').on('keydown.emoji', e => {
    if (e.which === 27) {
      closeSelector();
      return false;
    }
  });
}

export { showSelector };
