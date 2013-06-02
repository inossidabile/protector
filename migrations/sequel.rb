### Connection

DB = Sequel.sqlite

Sequel::Model.instance_eval do
  def none
    where('1 = 0')
  end
end

### Tables

[:dummies, :fluffies, :bobbies].each do |m|
  DB.create_table m do
    primary_key :id
    String :string
    Integer :number
    Text :text
    Integer :dummy_id
  end
end

DB.create_table :loonies do
  Integer :fluffy_id
  String :string
end

### Classes

class Dummy < Sequel::Model
  one_to_many :fluffies
  one_to_many :bobbies
end

class Fluffy < Sequel::Model
  many_to_one :dummy
  one_to_one :loony
end

class Bobby < Sequel::Model
end

class Loony < Sequel::Model
end