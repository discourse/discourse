/* global settings */

import Card from "discourse/blocks/builtin/card";
import Heading from "discourse/blocks/builtin/heading";
import Layout from "discourse/blocks/builtin/layout";
import Paragraph from "discourse/blocks/builtin/paragraph";
import Section from "discourse/blocks/builtin/section";
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const image = (name) => ({
    url: settings.theme_uploads[name],
    source: "url",
    width: name === "curator" ? 400 : 600,
    height: name === "curator" ? 650 : 400,
  });
  const card = (id, args, column, row) => ({
    block: Card,
    id,
    args,
    ...(column ? { containerArgs: { grid: { column, row } } } : {}),
  });
  const heading = (text) => ({ block: Heading, args: { text, level: 2 } });
  const placeholder = (text, column, row) => ({
    block: Paragraph,
    args: { text },
    classNames: "wf-card-reference-placeholder",
    ...(column ? { containerArgs: { grid: { column, row } } } : {}),
  });

  const mediaStories = [
    card("meta-sam", {
      title: "What a Decade of Running Discourse Taught Sam Saffron About AI in Communities",
      presentation: "above", image: image("prism"),
      identityEnabled: true, identityName: "Sam Saffron", identityRole: "Co-founder, Discourse",
      avatar: image("curator"), identityPlacement: "media", identityFormat: "feature",
      eyebrow: "Podcast", icon: "headphones", iconTarget: "label", labelStyle: "badge",
      actionLabel: "Watch now", href: "/latest", meta: "42 min",
    }),
    card("meta-hawk", {
      title: "The complete guide to building your Online Community",
      presentation: "above", image: image("space"),
      identityEnabled: true, identityName: "Hawk", identityRole: "CEO, Discourse",
      avatarDisplay: "initials", identityPlacement: "media", identityFormat: "stacked",
      eyebrow: "Video", icon: "play", iconTarget: "label", labelStyle: "badge",
      actionLabel: "Watch now", href: "/latest",
    }),
    card("meta-falling-apart", {
      title: "Why Online Communities Keep Falling Apart (And How to Fix Them)",
      presentation: "above", image: image("cells"),
      identityEnabled: true, identityName: "Sam Saffron", identityRole: "Co-founder, Discourse",
      avatar: image("curator"), identityPlacement: "media", identityTreatment: "photo",
      eyebrow: "Podcast", actionLabel: "Watch now", href: "/latest",
    }),
  ];

  const hubspot = (id, champion, surface) => ({
    block: Section, id, args: { surface },
    children: [
      placeholder("HubSpot header and hero — outside this Card study"),
      heading("Latest topics"),
      {
        block: Layout, args: { mode: "grid", columns: 3, rows: 1 },
        children: [
          placeholder("Topics — live-data placeholder", "1 / 3", "1"),
          {
            block: Layout, args: { mode: "stack" },
            containerArgs: { grid: { column: "3", row: "1" } },
            children: [
              card(`${id}-newsletter`, {
                title: "Community newsletter", icon: "envelope", dividers: true,
                body: "We're curating a weekly newsletter designed to assist you in discovering content in the community.",
                presentation: "none", surface: "subtle", actionLabel: "Sign up", href: "/latest",
              }),
              placeholder("Much loved today — live member list placeholder"),
            ],
          },
        ],
      },
      heading("Community spotlight"),
      {
        block: Layout, args: { mode: "grid", columns: 3, rows: 3 },
        children: [
          card(`${id}-champion`, {
            title: champion, eyebrow: "Champion of the month", labelStyle: "badge", labelPlacement: "media",
            body: "Making waves with innovative solutions and exceptional community leadership.",
            image: image("curator"), presentation: "behind", actionLabel: "Read full story", href: "/latest",
          }, "1", "1 / 3"),
          card(`${id}-programme`, {
            title: "Join the Champions Program", icon: "award", iconStyle: "tile", presentation: "none",
            body: "Share your expertise, help others, and get exclusive benefits.",
            actionLabel: "Become a champion", href: "/latest",
          }, "1", "3"),
          card(`${id}-highlight`, {
            title: "What does UNBOUND mean to you?", eyebrow: "UNBOUND",
            image: image("space"), presentation: "behind", actionLabel: "Explore the story", href: "/latest",
          }, "2 / 4", "1"),
          card(`${id}-roundtable`, {
            title: "How context is reshaping competitive advantage", eyebrow: "Webinars",
            body: "A roundtable conversation about the opportunities ahead.",
            presentation: "none", actionLabel: "Watch the roundtable", href: "/latest",
          }, "2", "2 / 4"),
          card(`${id}-agents`, {
            title: "AI agents on your GTM team: from first steps to revenue", eyebrow: "Webinars",
            image: image("cells"), presentation: "above", actionLabel: "Watch now", href: "/latest",
          }, "3", "2 / 4"),
        ],
      },
      placeholder("Explore by hub — category-data placeholder"),
    ],
  });

  api.renderBlocks("hero-blocks", [placeholder("Site hero — outside this Card study")]);
  api.renderBlocks("sidebar-blocks", [placeholder("Site navigation — outside this Card study")]);
  api.renderBlocks("main-outlet-blocks", [
    {
      block: Section, id: "museum-discussions", args: { surface: "transparent" },
      children: [placeholder("Museum hero — heading, image and actions are outside this Card study"), heading("Latest discussions"), {
        block: Layout, args: { mode: "grid", columns: 3, rows: 1 },
        children: [
          placeholder("Latest discussions — live-data placeholder", "1 / 3", "1"),
          { block: Layout, args: { mode: "stack" }, containerArgs: { grid: { column: "3", row: "1" } }, children: [
            card("museum-newsletter", {
              title: "Community newsletter", body: "Curated museum stories, upcoming events, and discussions delivered weekly.",
              icon: "envelope", presentation: "none", dividers: true, surface: "subtle",
              actionLabel: "Sign up", href: "/latest",
            }),
            placeholder("Contributors — live-data placeholder"),
          ] },
        ],
      }],
    },
    {
      block: Section, id: "museum-cards", args: { surface: "subtle" },
      children: [heading("From the museum"), {
        block: Layout, args: { mode: "grid", columns: 3, rows: 2 },
        children: [
          card("museum-curator", {
            title: "Meet our curator: Dr. Maya Chen", body: "Learn about her journey, research, and the stories behind Beyond the Visible.",
            image: image("curator"), presentation: "behind", actionLabel: "Read the interview", href: "/latest",
          }, "1", "1 / 3"),
          card("museum-exhibition", {
            eyebrow: "Exhibition highlight", title: "Beyond the Visible opens this month",
            body: "Discover the science of the unseen through hands-on exhibits and immersive experiences.",
            image: image("prism"), presentation: "behind", actionLabel: "Plan your visit", href: "/latest",
          }, "2 / 4", "1"),
          card("museum-neutrino", {
            eyebrow: "Collection story", title: "The Neutrino Mystery", body: "Latest findings from IceCube Observatory",
            image: image("cells"), presentation: "above", actionLabel: "Read more", href: "/latest",
          }, "2", "2"),
          card("museum-ethics", {
            eyebrow: "Member spotlight", title: "CRISPR Ethics", body: "Where do we draw the line?",
            image: image("space"), presentation: "above", actionLabel: "Read more", href: "/latest",
          }, "3", "2"),
        ],
      }, placeholder("Explore the museum — category-data placeholder")],
    },
    {
      block: Section, id: "meta-cards", args: { surface: "accent" },
      children: [placeholder("Meta discussions, events and contributors — live-data placeholders"), heading("Watch & Listen"), {
        block: Layout, args: { mode: "row" }, children: mediaStories,
      }, card("meta-guide", {
        presentation: "none", title: "Secure by Design: Our free guide to building privacy-focused communities",
        body: "Discover how to design a foundation of trust for your community.",
        actionLabel: "Download your copy", href: "/latest", actionStyle: "button", actionLayout: "inline", surface: "accent",
      })],
    },
    hubspot("hubspot-dark", "Gabriel Marguglio", "accent"),
    hubspot("hubspot-light", "Cory Mitchell", "subtle"),
    {
      block: Section, id: "andela-reference", args: { surface: "subtle" },
      children: [
        heading("Andela reference"),
        placeholder("Welcome back — heading and action, not a Card"),
        placeholder("Save the dates — live event cards"),
        placeholder("Latest topics — live discussions"),
        placeholder("Grow, together — live member milestones"),
        placeholder("Come chat with us — live channel cards"),
      ],
    },
    {
      block: Section, id: "populii-cards", args: { surface: "subtle" },
      children: [
        placeholder("Populii header and navigation — outside this Card study"),
        card("populii-atlas", {
          title: "Earn money by fixing maps on your phone", body: "Join the Atlas Project and make fast, easy map improvements from anywhere.",
          image: image("curator"), presentation: "beside", imageSide: "end", imageWidth: "even", scale: "featured",
          actionStyle: "button", actionLabel: "Sign up for Atlas Project", href: "/latest",
        }),
        placeholder("Categories — live-data placeholder"),
        {
          block: Layout, args: { mode: "row" }, children: [
            card("populii-gig", {
              eyebrow: "My current gig", title: "Atlas Project", presentation: "none", surface: "accent",
              body: "Check out the conversations happening in this gig if you are involved right now.",
              href: "/latest", wholeCard: true,
            }),
            card("populii-course", {
              eyebrow: "Hot learning resource", title: "Chatbot evaluation course", presentation: "none", surface: "contrast",
              body: "A collection of 15 videos that teach you how to build a chatbot from A to Z.",
              href: "/latest", wholeCard: true,
            }),
          ],
        },
        placeholder("Community discussions — live-data placeholder"),
      ],
    },
    {
      block: Section, id: "meta-below", args: { surface: "accent" },
      children: [heading("Watch & Listen — image below"), {
        block: Layout, args: { mode: "row" },
        children: mediaStories.map((story) => ({
          ...story, id: `${story.id}-below`, args: { ...story.args, presentation: "below" },
        })),
      }],
    },
    {
      block: Section, id: "card-keyboard",
      children: [
        heading("Independent Card links"),
        card("keyboard-actions", {
          title: "Explore the exhibition", presentation: "none", wholeCard: true,
          body: {
            type: "doc", content: [
              { type: "text", text: "Read the " },
              { type: "text", text: "visitor guide", marks: [{ type: "link", attrs: { href: "#card-body" } }] },
              { type: "text", text: " before booking." },
            ],
          },
          href: "#card-primary", actionLabel: "Book your visit",
          secondaryEnabled: true, secondaryLabel: "Read the transcript", secondaryHref: "#card-secondary",
        }),
        card("keyboard-whole", {
          title: "Explore the collection", presentation: "none", wholeCard: true,
          href: "#card-whole",
        }),
      ],
    },
    {
      block: Section, id: "card-stress", args: { backgroundImage: image("cells"), scrim: "strong" },
      children: [heading("Everything filled — an intentional stress case"), {
        block: Layout, args: { mode: "row" },
        children: ["above", "below", "beside", "behind"].map((presentation) => card(`stress-${presentation}`, {
          title: "Building communities that last: a conversation about belonging, trust, and the work we do together",
          body: "A deliberately long description for authors who fill every optional field. Nothing should be cut off to make this card look tidier. Discover practical lessons, unexpected challenges, and ideas to bring back to your own community.",
          meta: "Recorded live · 1 hour 42 minutes · Includes a transcript and additional reading",
          eyebrow: "Special extended community conversation", icon: "headphones", iconTarget: "label", labelStyle: "badge",
          presentation, image: { ...image("prism"), dark: image("space") },
          imageDecorative: false, imageAlt: "A prism splitting light into a spectrum", imageWidth: "even",
          identityEnabled: true, identityName: "Dr. Alexandra Community-Builder", identityRole: "Director of community research and collaborative learning",
          avatar: { ...image("curator"), dark: image("curator") }, identityFormat: "feature", identityPlacement: "media",
          actionLabel: "Watch the complete conversation", href: "/latest", external: true,
          secondaryEnabled: true, secondaryLabel: "Read the transcript and resources", secondaryHref: "/about", secondaryExternal: true,
          dividers: true, scale: "featured", surface: "integrated",
        })),
      }],
    },
  ].map((section) => ({
    ...section,
    children: [{ block: Layout, args: { mode: "stack", gap: 1.5 }, children: section.children }],
  })));
});
