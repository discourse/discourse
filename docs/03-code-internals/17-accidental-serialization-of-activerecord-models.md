---
title: Preventing accidental serialization of ActiveRecord models
short_title: Accidental serialization of ActiveRecord models
id: accidental-serialization-of-activerecord-model

---
We've introduced a patch to prevent the accidental serialization of ActiveRecord models without specifying the fields to be serialized. This change ensures that we control which fields are included, avoiding potential issues with incomplete or excessive data being exposed.

By default, rendering an ActiveRecord model as JSON includes all attributes, which may not be desirable in many cases. To enforce better practices, we need to specify which fields should be serialized.

### Usage Examples

**Incorrect Usage:**
```ruby
def show
  @user = User.first
  render json: @user
end
```
In development and tests, this will result in:

```
ActiveRecordSerializationSafety::BlockedSerializationError:
Serializing ActiveRecord models (User) without specifying fields is not allowed.
Use a Serializer, or pass the :only option to #serializable_hash. More info: https://meta.discourse.org/t/-/314495    
./lib/freedom_patches/active_record_disable_serialization.rb:15:in `serializable_hash'
```

**Correct Usage:**

1. Using a Serializer

```ruby
class UserSerializer < ApplicationSerializer
  attributes :id, :email
end

def show
  @user = User.first
  render json: @user, serializer: UserSerializer
end
```
2. Using the `:only` option

```ruby
def show
  @user = User.first
  render json: @user.as_json(only: [:id, :email])
end
```
