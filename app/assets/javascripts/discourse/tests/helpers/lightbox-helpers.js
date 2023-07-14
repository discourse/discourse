import { htmlSafe } from "@ember/template";

// we use transparent pngs here to avoid loading actual images in tests. We don't care so much about the content of the image
// we only care that the correct loading state is set and the metadata is correct
const PNGS = {
  first: {
    fullsizeURL:
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAC7gAAAAKCAYAAAAkEBP9AAAAqElEQVR42u3aQQEAIAwAIdfN/pVmDO8BOZizdw8AAAAAAAAAAAAAAHw2gjsAAAAAAAAAAAAAAAWCOwAAAAAAAAAAAAAACYI7AAAAAAAAAAAAAAAJgjsAAAAAAAAAAAAAAAmCOwAAAAAAAAAAAAAACYI7AAAAAAAAAAAAAAAJgjsAAAAAAAAAAAAAAAmCOwAAAAAAAAAAAAAACYI7AAAAAAAAAAAAAAAJD2GpFp8NV4+AAAAAAElFTkSuQmCC",
    smallURL:
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAfQAAAABCAYAAAAo/lyUAAAAG0lEQVR42mP8z8AARKNgFIyCUTAKRsEoGMoAAJ3mAgDVocSsAAAAAElFTkSuQmCC",
  },
  second: {
    fullsizeURL:
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAA+gAAAACCAYAAADLlPadAAAAJ0lEQVR42u3XMQEAAAgDoNk/pzk0xh5owdzmAgAAAFSNoAMAAEDfA6HNBcm32R2bAAAAAElFTkSuQmCC",
    smallURL:
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAfQAAAABCAYAAAAo/lyUAAAAHElEQVR42mP8/5ThP8MoGAWjYBSMglEwCoY0AACaegLl/taPAQAAAABJRU5ErkJggg==",
  },
  third: {
    fullsizeURL:
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAA+gAAAACCAYAAADLlPadAAAAJklEQVR42u3XMQEAAAgDoPnZv7DG2AMtmNxeAAAAgKoRdAAAAOh7JuQED1zV49EAAAAASUVORK5CYII=",
    smallURL:
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAfQAAAABCAYAAAAo/lyUAAAAHElEQVR42mNk+M/xn2EUjIJRMApGwSgYBUMaAADbVwIINvIVWgAAAABJRU5ErkJggg==",
  },
  smallerThanViewPort: {
    fullsizeURL:
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAASwAAAACCAYAAADirOGHAAAAIUlEQVR42u3UAQ0AAAgDoNvE/iU1xzcIwWTvAlBghAW0eNbwBD9majEtAAAAAElFTkSuQmCC",
    smallURL:
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAJYAAAABCAYAAAA8YlcZAAAAE0lEQVR42mNkUPj/n2EUjAIqAwD2IwIg6SI42wAAAABJRU5ErkJggg==",
  },
};

const cssVars1 = htmlSafe(
  `--dominant-color: #F0F1F3;--aspect-ratio: 3000 / 10;--small-url: url(${PNGS.first.smallURL});`
);
const cssVars2 = htmlSafe(
  `--dominant-color: #F0F1F3;--aspect-ratio: 3000 / 10;--small-url: url(${PNGS.second.smallURL});`
);
const cssVars3 = htmlSafe(
  `--dominant-color: #F0F1F3;--aspect-ratio: 3000 / 10;--small-url: url(${PNGS.third.smallURL});`
);
const cssVars4 = htmlSafe(
  `--dominant-color: #F0F1F3;--aspect-ratio: 3000 / 10;--small-url: url(${PNGS.smallerThanViewPort.smallURL});`
);

export const LIGHTBOX_IMAGE_FIXTURES = {
  first: {
    fullsizeURL: PNGS.first.fullsizeURL,
    smallURL: PNGS.first.smallURL,
    downloadURL: PNGS.first.fullsizeURL,
    fileDetails: "3000×10 221 KB",
    width: 3000,
    height: 10,
    aspectRatio: "3000 / 10",
    dominantColor: "F0F1F3",
    index: 0,
    title: "first image title",
    alt: "first image alt",
    cssVars: cssVars1,
  },
  second: {
    fullsizeURL: PNGS.second.fullsizeURL,
    smallURL: PNGS.second.smallURL,
    downloadURL: PNGS.second.fullsizeURL,
    fileDetails: "1000×2 166 KB",
    width: 1000,
    height: 2,
    aspectRatio: "1000 / 2",
    dominantColor: "F9F5F6",
    index: 1,
    title: "second image title",
    alt: "second image alt",
    cssVars: cssVars2,
  },
  third: {
    fullsizeURL: PNGS.third.fullsizeURL,
    smallURL: PNGS.third.smallURL,
    downloadURL: PNGS.third.fullsizeURL,
    fileDetails: "1000×2 240 KB",
    width: 1000,
    height: 2,
    aspectRatio: "1000 / 2",
    dominantColor: "EEF0EE",
    index: 2,
    title: "third image title",
    alt: "third image alt",
    cssVars: cssVars3,
  },
  smallerThanViewPort: {
    fullsizeURL: PNGS.smallerThanViewPort.fullsizeURL,
    smallURL: PNGS.smallerThanViewPort.smallURL,
    downloadURL: PNGS.smallerThanViewPort.fullsizeURL,
    fileDetails: "300×2 92.3 KB",
    width: 300,
    height: 2,
    aspectRatio: "300 / 2",
    dominantColor: "F0F0F1",
    index: 3,
    title: "fourth image title",
    alt: "fourth image alt",
    cssVars: cssVars4,
  },
  invalidImage: {
    fullsizeURL: `https:expected-lightbox-invalid/.image/404.png`,
  },
};

export function generateLightboxObject() {
  const trimmedLighboxItem = Object.keys(LIGHTBOX_IMAGE_FIXTURES.first).reduce(
    (acc, key) => {
      if (key !== "height" && key !== "width" && key !== "alt") {
        acc[key] = LIGHTBOX_IMAGE_FIXTURES.first[key];
      }
      return acc;
    },
    {}
  );

  return {
    items: [{ ...trimmedLighboxItem }],
    startingIndex: 0,
    callbacks: {},
    options: {},
  };
}

export function generateLightboxMarkup(
  {
    fullsizeURL,
    smallURL,
    downloadURL,
    title,
    fileDetails,
    dominantColor,
    aspectRatio,
    alt,
    height,
    width,
  } = { ...LIGHTBOX_IMAGE_FIXTURES.first }
) {
  return `
  <div class="lightbox-wrapper">
    <a class="lightbox" href="${fullsizeURL}"
      data-download-href="${downloadURL}"
      title="${title}"><img src="${smallURL}" title="${title}" alt="${alt}"
        width="${width}" height="${height}"
        data-dominant-color="${dominantColor}" loading="lazy"
        style="aspect-ratio: ${aspectRatio}" />
      <div class="meta">
        <span class="filename">${title}</span><span
          class="informations">${fileDetails}</span>
      </div>
    </a>
  </div>
`;
}

export function generateImageUploaderMarkup(
  fullsizeURL = LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL
) {
  return `
<div id="profile-background-uploader" class="image-uploader ember-view">
  <div class="uploaded-image-preview input-xxlarge"
    style="background-image: url(${fullsizeURL})">
    <a class="lightbox"
      href="${fullsizeURL}"
      rel="nofollow ugc noopener">
      <div class="meta">
        <span class="informations">
          x
        </span>
      </div>
    </a>
  </div>
</div>
`;
}
