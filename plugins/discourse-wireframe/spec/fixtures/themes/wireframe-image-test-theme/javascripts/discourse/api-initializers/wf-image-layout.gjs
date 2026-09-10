import ButtonLink from "discourse/blocks/builtin/button-link";
import Heading from "discourse/blocks/builtin/heading";
import Image from "discourse/blocks/builtin/image";
import Layout from "discourse/blocks/builtin/layout";
import Paragraph from "discourse/blocks/builtin/paragraph";
import Section from "discourse/blocks/builtin/section";
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const image = { url: "/images/discourse-logo-sketch.png", source: "url", width: 1858, height: 512 };
  api.renderBlocks("main-outlet-blocks", [
    { block: Section, args: { accessibleLabel: "Featured community", backgroundImage: image, minHeight: "medium" }, children: [
      { block: Layout, args: { mode: "grid", columns: 1, rows: 1 }, children: [
      { block: Layout, args: { mode: "grid", columns: 2, rows: 1 }, containerArgs: { grid: { column: "1", row: "1" } }, children: [
        { block: Heading, args: { text: "Our community" }, containerArgs: { grid: { column: "1", row: "1" } } },
        { block: Image, args: { image: { ...image, dark: { url: "/images/d-logo-sketch.png", source: "url", width: 244, height: 66 }, frame: { width: 120, height: 80 } }, alt: "Grid image" }, containerArgs: { grid: { column: "2", row: "1" } } },
      ] },
      ] },
    ] },
    { block: Image, args: { image: { ...image, frame: { width: 400, height: 240 } }, alt: "Discourse community", caption: "A shared image frame" } },
    { block: Paragraph, args: { text: "Discover stories from our community." } },
    { block: ButtonLink, args: { label: "Explore the community", href: "/latest", variant: "primary" } },
  ]);
});
