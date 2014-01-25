# Protector

[![Gem Version](https://badge.fury.io/rb/protector.png)](http://badge.fury.io/rb/protector)
[![Build Status](https://travis-ci.org/inossidabile/protector.png?branch=master)](https://travis-ci.org/inossidabile/protector)
[![Code Climate](https://codeclimate.com/github/inossidabile/protector.png)](https://codeclimate.com/github/inossidabile/protector)

Protector is a Ruby ORM extension for managing security restrictions on a field level. The gem favors white-listing over black-listing (everything is disallowed by default), convention over configuration and is duck-type compatible with most of existing code.

Currently Protector supports the following ORM adapters:

  * [ActiveRecord](http://guides.rubyonrails.org/active_record_querying.html) (>= 3.2.9)
  * [Sequel](http://sequel.rubyforge.org/) (>= 3.30.0)

We are working hard to extend the list with:

  * [Mongoid](http://mongoid.org/en/mongoid/index.html)
  * [ROM](https://github.com/rom-rb/rom)

## Compatibility

Protector is an extension and therefore hides deeply inside your ORM library making itself compatible to the most gems you use. Sometimes however, you might need additional integration to take the best from it:

  * [Protector and Strong Parameters](https://github.com/inossidabile/protector/wiki/Protector-and-Strong-Parameters)
  * [Protector and InheritedResources](https://github.com/inossidabile/protector/wiki/Protector-and-Inherited-Resources)
  * [Protector and CanCan](https://github.com/inossidabile/protector/wiki/Protector-and-CanCan)
  * [Protector and SimpleForm](https://github.com/inossidabile/protector/wiki/Protector-and-SimpleForm)

## Basics

DSL of Protector is a Ruby block (or several) describing ACL separated into contexts (authorized user is a very typical example of a context). Each time the context of model changes, DSL blocks reevaluate internally to get an actual ACL that is then utilized internally to cut restricted actions.

Protector follows nondestructive blocking strategy. It returns `nil` when the forbidden field is requested and only checks creation (modification) capability during persisting. Even more: the latter is implemented as a model validation so it will seamlessly integrate into your typical workflow.

This example is based on ActiveRecord but the code is mostly identical for any supported adapter.

```ruby
class Article < ActiveRecord::Base          # Fields: title, text, user_id, hidden
  protect do |user|                         # `user` is a context of security

    if user.admin?
      scope { all }                         # Admins can retrieve anything

      can :read                             # ... and view anything
      can :create                           # ... and create anything
      can :update                           # ... and update anything
      can :destroy                          # ... and they can delete
    else
      scope { where(hidden: false) }        # Non-admins can only read insecure data

      can :read                             # Allow to read any field
      if user.nil?                          # User is unknown and therefore not authenticated
        cannot :read, :text                 # Guests can't read the text
      end

      can :create, %w(title text)           # Non-admins can't set `hidden` flag
      can :create, user_id: labmda{|x|      # ... and should correctly fill 
        x == user.id                        # ... the `user_id` association
      }

      # In this setup non-admins can not destroy or update existing records.
    end
  end
end
```

Inside your model, you can have several `protect` calls that will get merged. Using this you can move basic rules to a separate module to keep code DRY.

Now that we have ACL described we can enable it as easy as:

```ruby
article.restrict!(current_user)    # Assuming article is an instance of Article
```

If `current_user` is a guest we will get `nil` from `article.text`. At the same time we will get validation error if we pass any fields but title, text and user_id (equal to our own id) on creation.

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

Be aware that if you already made the database query the scope has no effect on the already fatched data. This is because Protector is working on two levels: first during retrieval (scops are applied here) and after that on the level of fields. So for example `find` and `restrict!` calls are not commutative:
```ruby
# Should be used if you are using scops for visibility restriction 
Article.restrict!(current_user).find(3)

# not equal!
# Will select the record with id: 3 regardless of any scops and only restrict on the field level
Article.find(3).restrict!(current_user)
```

Note also that you don't need to explicitly restrict models you get from a restricted scope – they born restricted.

**Important**: unlike fields, scopes follow black-list approach by default. It means that you will NOT restrict selection in any way if no scope was set within protection block! This arguably is the best default strategy. But it's not the only one – see `paranoid` at the [list of available options](https://github.com/inossidabile/protector#options) for details.


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

Protector is aware of associations. All the associations retrieved from restricted instance will automatically be restricted to the same context. Therefore you don't have to do anything special – it will respect proper scopes out of the box:

```ruby
foo.restrict!(current_user).bar         # bar is automatically restricted by `current_user`
```

Remember however that auto-restriction is only enabled for reading. Passing a model (or an array of those) to an association will not auto-restrict it. You should handle it manually.

The access to `belongs_to` kind of association depends on corresponding foreign key readability.

## Eager Loading

Both of eager loading strategies (separate query and JOIN) are fully supported.

## Manual checks and custom actions

Each restricted model responds to the following methods:

* `visible?` – determines if the model is visible through restriction scope
* `creatable?` – determines if you pass validation on creation with the fields you set
* `updatable?` – determines if you pass validation on update with the fields you changed
* `destroyable?` – determines if you can destroy the model

In fact Protector does not limit you to `:read`, `:update` and `:create` actions. They are just used internally. You however can define any other to make custom roles and restrictions. All of them are able to work on a field level.

```ruby
protect do
  can :drink, :field1         # Allows `drink` action with field1
  can :eat                    # Allows `eat` action with any field
end
```

To check against custom actions use `can?` method:

```ruby
model.can?(:drink, :field2)   # Checks if model can drink field2
model.can?(:drink)            # Checks if model can drink any field
```

As you can see you don't have to use fields. You can use `can :foo` and `can? :foo`. While they will bound to fields internally it will work like you expect for empty sets.

## Global switch

Sometimes for different reasons (like debug or whatever) you might want to run piece of code having Protector totally disabled. There is a way to do that:

```ruby
Protector.insecurely do
  # anything here
end
```

No matter what happens inside, all your entities will act unprotected. So use with **EXTREME** caution.

Please note also that we are talking about "unprotected" and "disabled". It does not make `can?` to always return `true`. Instead `can?` would thrown an exception just like it does for any unprotected model. Any other approach makes logic incostitent, unpredictable and just dangerous. There are different possible strategies to isolate business logic from security domain in tests like direct `can?` mocking or forcing admin role to a test user. Use them whenever you want to abstract from security in a whole and `insecurely` when you want to mock a model to the basic security state.

## Ideology

Protector is a successor to [Heimdallr](https://github.com/inossidabile/heimdallr). The latter being a proof-of-concept appeared to be way too paranoid and incompatible with the rest of the world. Protector re-implements same idea keeping the Ruby way:

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

## Options

Use `Protector.config.option = value` to assign an option. Available options are:

  * **paranoid**: makes scope management white-listed. If set to `true` will force Protector to return empty scope when no scope was given within a protection block.
  * **strong_parameters**: set to `false` to disable built-in [Strong Parameters integration](https://github.com/inossidabile/protector/wiki/Protector-and-Strong-Parameters).

Protector features basic Rails integration so you can assign options using `config.protector.option = value` at your `config/*.rb`.

## Need help?

  * Use [StackOverflow](http://stackoverflow.com/questions/tagged/protector) Luke! Make sure to use tag `protector`.
  * You can get help at [irc.freenode.net](http://freenode.net) #protector.rb.

## Maintainers

* Boris Staal, [@inossidabile](http://staal.io)

## License

It is free software, and may be redistributed under the terms of MIT license.

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/inossidabile/protector/trend.png)](https://bitdeli.com/free "Bitdeli Badge")
