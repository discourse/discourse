const root = window.location.href.replace(/\/[^/]*$/, "");

const IMAGE_FOLDER = `${root}/images/lightbox`;

export const LIGHTBOX_IMAGE_FIXTURES = {
  first: {
    fullsizeURL: `${IMAGE_FOLDER}/first_large.png`,
    smallURL: `${IMAGE_FOLDER}/first_small.png`,
    downloadURL: `${IMAGE_FOLDER}/first_download.png`,
    fileDetails: "1068×1518 221 KB",
    width: 1068,
    height: 1518,
    aspectRatio: "351 / 500",
    dominantColor: "F0F1F3",
    index: 0,
    title: "first image title",
    alt: "first image alt",
    cssVars: `--dominant-color: #F0F1F3;--aspect-ratio: 351 / 500;--small-url: url(${IMAGE_FOLDER}/first_small.png);`,
  },
  second: {
    fullsizeURL: `${IMAGE_FOLDER}/second_large.png`,
    smallURL: `${IMAGE_FOLDER}/second_small.png`,
    downloadURL: `${IMAGE_FOLDER}/second_download.png`,
    fileDetails: "1068×1609 166 KB",
    width: 1068,
    height: 1609,
    aspectRatio: "331 / 500",
    dominantColor: "F9F5F6",
    index: 1,
    title: "second image title",
    alt: "second image alt",
    cssVars: `--dominant-color: #F9F5F6;--aspect-ratio: 331 / 500;--small-url: url(${IMAGE_FOLDER}/second_small.png);`,
  },
  third: {
    fullsizeURL: `${IMAGE_FOLDER}/third_large.png`,
    smallURL: `${IMAGE_FOLDER}/third_small.png`,
    downloadURL: `${IMAGE_FOLDER}/third_download.png`,
    fileDetails: "1068×1518 240 KB",
    width: 1068,
    height: 1518,
    aspectRatio: "331 / 500",
    dominantColor: "EEF0EE",
    index: 2,
    title: "third image title",
    alt: "third image alt",
    cssVars: `--dominant-color: #EEF0EE;--aspect-ratio: 331 / 500;--small-url: url(${IMAGE_FOLDER}/third_small.png);`,
  },
  smallerThanViewPort: {
    fullsizeURL: `${IMAGE_FOLDER}/fourth_large.png`,
    smallURL: `${IMAGE_FOLDER}/fourth_small.png`,
    downloadURL: `${IMAGE_FOLDER}/fourth_download.png`,
    fileDetails: "700×273 92.3 KB",
    width: 700,
    height: 273,
    aspectRatio: "690 / 269",
    dominantColor: "F0F0F1",
    index: 3,
    title: "fourth image title",
    alt: "fourth image alt",
    cssVars: `--dominant-color: #F0F0F1;--aspect-ratio: 690 / 269;--small-url: url(${IMAGE_FOLDER}/fourth_small.png);`,
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
