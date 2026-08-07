# frozen_string_literal: true

# Builds random human-friendly usernames (e.g. "QuietFalcon") for accounts
# created without user input, where no signup data can (or may) be used to
# derive one. Word lists are English but always produce valid ASCII
# usernames, so they work regardless of the site's locale settings.
module RandomUsernameGenerator
  ADJECTIVES = %w[
    agile
    amber
    azure
    bold
    brave
    breezy
    bright
    calm
    candid
    cheery
    civic
    clever
    cosmic
    crisp
    curious
    daring
    deft
    eager
    earnest
    fabled
    gentle
    golden
    happy
    hardy
    hearty
    humble
    jolly
    keen
    kind
    lively
    lucid
    lunar
    mellow
    merry
    mighty
    nimble
    noble
    plucky
    proud
    quick
    quiet
    rapid
    rustic
    silent
    silver
    smart
    snappy
    solar
    stellar
    sunny
    swift
    tidy
    upbeat
    valiant
    vivid
    warm
    witty
    zesty
  ].freeze

  NOUNS = %w[
    acorn
    badger
    beacon
    bison
    breeze
    brook
    canyon
    cedar
    comet
    condor
    coral
    cougar
    coyote
    crane
    cricket
    dolphin
    ember
    falcon
    fern
    finch
    fjord
    fox
    gecko
    glacier
    harbor
    heron
    hawk
    ibis
    jaguar
    lagoon
    lark
    lemur
    lynx
    maple
    marmot
    meadow
    meteor
    nebula
    newt
    orca
    osprey
    otter
    owl
    panda
    pebble
    penguin
    pine
    prairie
    puffin
    quokka
    raven
    reef
    river
    sequoia
    sparrow
    summit
    tundra
    walrus
    willow
    wren
    zephyr
  ].freeze

  def self.generate
    # A numeric suffix widens the namespace well beyond the word-pair count,
    # so very large sites don't exhaust it.
    candidate = "#{ADJECTIVES.sample.capitalize}#{NOUNS.sample.capitalize}#{rand(10..99)}"
    UserNameSuggester.find_available_username_based_on(
      UserNameSuggester.rightsize_username(candidate),
    )
  end
end
