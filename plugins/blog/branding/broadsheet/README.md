# Broadsheet

An editorial, newspaper-style reader theme. It pairs a large serif masthead and
headlines with small-caps sans kickers, double rules under the header and above
the footer, and a numbered story grid divided by column rules. The lead story
gets a typographic cover when it has no image, and articles open with a drop cap
and set block quotes as pull quotes.

The palette (newsprint paper, near-black ink, cobalt accent) stays configurable,
and every color comes from the blog's light/dark tokens, so dark mode needs no
extra rules. System serif and sans stacks avoid font downloads. No JavaScript is
required.

It ships as an included theme under **Admin → Plugins → Blog → Themes**. Preview
or activate it from its card, or use **Customize** to create an editable draft.
Rendering coverage is in `spec/requests/themes_spec.rb` under "Broadsheet preset".
