const HTTP_MAILTO_REGEX = new RegExp(
  /(?:(?:(https|http|ftp)+):\/\/)?(?:\S+(?::\S*)?(@))?(?:(?:([a-z0-9][a-z0-9\-]*)?[a-z0-9]+)(?:\.(?:[a-z0-9\-])*[a-z0-9]+)*(?:\.(?:[a-z]{2,})(:\d{1,5})?))(?:\/[^\s]*)?\s $/
);

// TODO use site settings

export default {
  inputRules: [
    {
      match: HTTP_MAILTO_REGEX,
      handler: (state, match, start, end) => {
        const markType = state.schema.marks.link;

        const resolvedStart = state.doc.resolve(start);
        if (!resolvedStart.parent.type.allowsMarkType(markType)) {
          return null;
        }

        const link = match[0].substring(0, match[0].length - 1);
        const linkAttrs =
          match[2] === "@"
            ? { href: "mailto:" + link }
            : { href: link, target: "_blank" };
        const linkTo = markType.create(linkAttrs);
        return state.tr
          .removeMark(start, end, markType)
          .addMark(start, end, linkTo)
          .insertText(match[5], start);
      },
    },
  ],
};
