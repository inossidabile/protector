# Protector

[![Build Status](https://travis-ci.org/inossidabile/protector.png?branch=master)](https://travis-ci.org/inossidabile/protector)
[![Code Climate](https://codeclimate.com/github/inossidabile/protector.png)](https://codeclimate.com/github/inossidabile/protector)

Protector is a Ruby ORM extension for managing security restrections on a field level. The gem favors whitelisting over blacklisting (everything is disallowed by default), convention over configuration and is duck-type compatible with most of existing code.

Currently Protector supports the following ORM adapters:

  * [ActiveRecord](http://guides.rubyonrails.org/active_record_querying.html) (>= 3.2)

We are working hard to extend the list with:

  * [Sequel](http://sequel.rubyforge.org/)
  * [DataMapper](http://datamapper.org/)
  * [Mongoid](http://mongoid.org/en/mongoid/index.html)

## Basics

DSL of Protector is a Ruby block (or several) describing ACL separated into contexts (authorized user is a very typical example of a context). Each time the context of model changes, DSL blocks reevaluate internally to get an actual ACL that is then utilized internally to cut restricted actions.

Protector follows an indestructive blocking strategy. It returns `nil` when the forbidden field is requested and only checks creation (modification) capability during persisting. Even more: the latter is implemented as a model validation so it will seamlessly integrate into your typical workflow.

This example is based on ActiveRecord but the code is mostly identical for any supported adapter.

```ruby
class Article < ActiveRecord::Base          # Fields: title, text, user_id, hidden
  protect do |user|                         # `user` is a context of security

    unless user.admin?
      scope { where(hidden: false) }        # Non-admins can only read insecure data

      can :view                             # Allow to read any field
      if user.nil?                          # User is unknown and therefore not authenticated
        cannot :view, :text                 # Guests can't read the text
      end

      can :create, %w(title text)           # Non-admins can't set `hidden` flag
      can :create, user_id: lamda{|x|       # ... and should correctly fill 
        x == user.id                        # ... the `user_id` association
      }

      # In this setup non-admins can not destroy or update existing records.
    else
      scope { all }                         # Admins can retrieve anything

      can :view                             # ... and view anything
      can :create                           # ... and create anything
      can :update                           # ... and update anything
      can :destroy                          # ... and they can delete
    end
  end
end
```

Now that we have ACL described we can enable it as easy as:

```ruby
article.restrict!(current_user)    # Assuming article is an instance of Article
```

To make model unsafe again call:

```ruby
article.unrestrict!
```

**Both methods are chainable!**

## Scopes

Besides the `can` and `cannot` directives Protector also handles relations visibility. In the previous sample the following block is responsible to make hidden articles actually hide:

```ruby
scope { where(hidden: false) }        # Non-admins can only read unsecure data
````

Make sure to write the block content of the `scope` directive in the notation of your ORM library.

To finally utilize this function use the same `restrict!` method on a level of Class or Relation. Like this:

```ruby
Article.restrict!(current_user).where(...)
# OR
Article.where(...).restrict!(current_user)
```

Note that you don't need to explicitly restrict models you get from a restricted scope – they born restricted.

## Self-aware conditions

Sometimes an access decision depends on the object we restrict. `protect` block accepts second argument to fulfill these cases. Keep in mind however that it's not always accessible: we don't have any instance for the restriction of relation and therefore `nil` is passed.

The following example extends Article to allow users edit their own posts:

```ruby
class Article < ActiveRecord::Base          # Fields: title, text, user_id, hidden
  protect do |user, article|
    if user
      if article.try(:user_id) == user.id   # Checks belonging keeping possible nil in mind
        can :update, %w(title text)         # Allow authors to modify posts
      end
    end
  end
end
```

## Associations

Protector is aware of associations. All the associations retrieved from restricted instance will automatically be restricted to the same context. Therefore you don't have to do anything special – it will respect proper scopes out of the box.

The access to `belongs_to` kind of association depends on corresponding foreign key readability.

## Ideology

Protector is successor to [Heimdallr](https://github.com/inossidabile/heimdallr). The latter being a proof-of-concept appeared to be way too paranoid and incompatible with the rest of the world. Protector brings the same idea into the Ruby way:

  * it works inside of the model instead of wrapping it into a proxy: that's why it's compatible with every other extension you use
  * it secures persistence and not object properties: you can modify any properties you want but it's not going to let you save what you can not save
  * it respects the differentiation between business-logic layer and SQL layer: protection is validation so any method that skips validation will also avoid the security check

**The last thing is really important to understand. No matter if you can read a field or not, methods like `.pluck` are still capable of reading any of your fields and if you tell your model to skip validation it will also skip an ACL check.**

## Installation

Add this line to your application's Gemfile:

    gem 'protector'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install protector

As long as you load Protector after an ORM library it is supposed to activate itself automatically. Otherwise you can enable required adapter manually:

```ruby
Protector::Adapters::ActiveRecord.activate!
```

Where "ActiveRecord" is the adapter you are about to use. It can be "Sequel", "DataMapper", "Mongoid".

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## LICENSE

It is free software, and may be redistributed under the terms of MIT license.
