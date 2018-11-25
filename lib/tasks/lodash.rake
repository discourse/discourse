# https://lodash.com/custom-builds
desc "Creates a custom lodash build"
task "lodash" do
  list = %w[
    sortBy
    groupBy
    every
    first
    last
    merge
    isEmpty
    chain
    filter
    extend
    omit
    union
    uniq
  ]

  system("yarn global add lodash-cli")
  system("lodash include=#{list.join(',')} minus=template -d -o ./vendor/assets/javascripts/lodash.js")
end
