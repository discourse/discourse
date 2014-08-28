# These routes must be loaded after all others.
# Routes are loaded in this order:
#
#  1. config/routes.rb
#  2. routes in engines
#  3. config/routes_last.rb

Discourse::Application.routes.draw do
  get "*url", to: 'permalinks#show'
end
