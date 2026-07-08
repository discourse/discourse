import { isEmpty } from "@ember/utils";

export function eventHasLivestream(event) {
  if (!event) {
    return false;
  }

  return (
    event.livestream &&
    !isEmpty(event.livestreamUrl) &&
    !isEmpty(event.livestreamOnebox)
  );
}

export function parseZoomJoinUrl(url) {
  if (!url) {
    return null;
  }

  try {
    const parsedUrl = new URL(url);

    if (!parsedUrl.hostname.match(/(^|\.)zoom\.us$/)) {
      return null;
    }

    const segments = parsedUrl.pathname.split("/").filter(Boolean);
    const segmentIndex = segments.findIndex((segment) =>
      ["j", "w", "wc"].includes(segment)
    );

    if (segmentIndex === -1) {
      return null;
    }

    const meetingNumber = segments[segmentIndex + 1];

    if (!meetingNumber?.match(/^\d+$/)) {
      return null;
    }

    return {
      meetingNumber,
      password: parsedUrl.searchParams.get("pwd"),
      url: parsedUrl.toString(),
    };
  } catch {
    return null;
  }
}

export function isSupportedZoomJoinUrl(url) {
  return !!parseZoomJoinUrl(url);
}
