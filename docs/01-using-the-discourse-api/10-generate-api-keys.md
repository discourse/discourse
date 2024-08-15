---
title: Generate User API Keys for testing
short_title: Generate API keys
id: generate-api-keys

---
Continuing the discussion from [User API keys specification](https://meta.discourse.org/t/user-api-keys-specification/48536):

I created a small utility script in order to test User API keys locally.

First install dependencies:

```
gem install addressable openssl base64 json
```

Then the script is here:

```ruby
require 'addressable'
require 'openssl'
require 'base64'
require 'json'

PRIVATE_KEY = OpenSSL::PKey::RSA.new(2048)
PUBLIC_KEY = PRIVATE_KEY.public_key

puts 'What is the target site?'
site = STDIN.gets.chomp

template = Addressable::Template.new("#{site}/user-api-key/new{?query*}")

url = template.expand({
  query: {
    application_name: 'ruby',
    client_id: `hostname`,
    scopes: 'read',
    public_key: PUBLIC_KEY,
    nonce: 1
  }
})

puts "navigate to #{url}."
puts
puts "copy the generated key in here"
puts
puts "press ENTER type end and press ENTER again"
puts

$/ = "end"
encoded_key = STDIN.gets.chomp


private_key = OpenSSL::PKey::RSA.new(PRIVATE_KEY)

user_api_key = JSON.parse(private_key.private_decrypt(Base64.decode64(encoded_key)))

puts "Your User API Key is #{user_api_key['key']}"
```
